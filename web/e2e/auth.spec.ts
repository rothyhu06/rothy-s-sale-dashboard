import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";
import { requireLocalSupabaseUrl } from "./support/local-supabase";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

test.describe("anonymous route boundary", () => {
  test("redirects an anonymous protected route to login", async ({ page }) => {
    await page.goto("/customers");

    await expect(page).toHaveURL(/\/login$/);
  });

  test("keeps the fictional design-system gallery public", async ({ page }) => {
    await page.goto("/design-system");

    await expect(page).toHaveURL(/\/design-system$/);
    await expect(page.getByRole("heading", { name: "CSIG Sales OS" })).toBeVisible();
  });
});

test.describe("authenticated login boundary", () => {
  test.describe.configure({ mode: "serial" });

  const email = `auth-e2e-${randomUUID()}@example.test`;
  const password = `Auth-e2e-${randomUUID()}!`;
  let localSupabaseUrl: URL | undefined;
  let userId: string;

  test.beforeAll(async () => {
    localSupabaseUrl = requireLocalSupabaseUrl(supabaseUrl);
    expect(supabaseAnonKey, "Export the local NEXT_PUBLIC_SUPABASE_ANON_KEY").toBeTruthy();
    expect(serviceRoleKey, "Export the local SUPABASE_SERVICE_ROLE_KEY for isolated test-user setup").toBeTruthy();

    const admin = createClient(localSupabaseUrl.href, serviceRoleKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    expect(error).toBeNull();
    expect(data.user).not.toBeNull();
    userId = data.user!.id;
  });

  test("redirects authenticated users and appends sanitized sign-in and sign-out audits", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("邮箱").fill(email);
    await page.getByLabel("密码").fill(password);
    await page.getByRole("button", { name: "登录" }).click();

    await expect(page).toHaveURL(/\/$/);
    await page.goto("/login");
    await expect(page).toHaveURL(/\/$/);

    await page.getByRole("button", { name: "退出登录" }).click();
    await expect(page).toHaveURL(/\/login$/);

    const verifier = createClient(localSupabaseUrl!.href, supabaseAnonKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    expect((await verifier.auth.signInWithPassword({ email, password })).error).toBeNull();

    const { data: auditRows, error: auditError } = await verifier
      .from("audit_logs")
      .select("action,entity_type,changed_fields,metadata,request_ip_hash,user_agent,error_code")
      .eq("owner_id", userId)
      .in("action", ["SignedIn", "SignedOut"])
      .order("occurred_at", { ascending: true });

    expect(auditError).toBeNull();
    expect(auditRows?.map(({ action }) => action)).toEqual(["SignedIn", "SignedOut"]);
    expect(auditRows?.every(({ entity_type }) => entity_type === "AuthSession")).toBe(true);
    const serializedAudit = JSON.stringify(auditRows);
    expect(serializedAudit).not.toContain(email);
    expect(serializedAudit).not.toContain(password);
    expect(serializedAudit.toLowerCase()).not.toContain("token");
  });
});
