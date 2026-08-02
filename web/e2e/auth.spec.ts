import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";

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
  let userId: string;

  test.beforeAll(async () => {
    expect(supabaseUrl, "Start local Supabase and export NEXT_PUBLIC_SUPABASE_URL").toBeTruthy();
    expect(supabaseAnonKey, "Export the local NEXT_PUBLIC_SUPABASE_ANON_KEY").toBeTruthy();
    expect(serviceRoleKey, "Export the local SUPABASE_SERVICE_ROLE_KEY for isolated test-user setup").toBeTruthy();

    const admin = createClient(supabaseUrl!, serviceRoleKey!, {
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

  test.afterAll(async () => {
    if (!userId || !supabaseUrl || !serviceRoleKey) return;

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { error } = await admin.auth.admin.deleteUser(userId);
    expect(error).toBeNull();
  });

  test("redirects an authenticated user away from login", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("邮箱").fill(email);
    await page.getByLabel("密码").fill(password);
    await page.getByRole("button", { name: "登录" }).click();

    await expect(page).toHaveURL(/\/$/);
    await page.goto("/login");
    await expect(page).toHaveURL(/\/$/);
  });
});
