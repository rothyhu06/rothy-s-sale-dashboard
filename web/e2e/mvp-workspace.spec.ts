import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { ensureDeterministicLocalUser } from "./support/local-test-user";
import { requireLocalSupabaseUrl } from "./support/local-supabase";

const email = "mvp-workspace@example.test";
const password = "Local-mvp-workspace-only!";

test.beforeAll(async () => {
  const url = requireLocalSupabaseUrl(process.env.NEXT_PUBLIC_SUPABASE_URL);
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  expect(key).toBeTruthy();
  const admin = createClient(url.href, key!, { auth: { autoRefreshToken: false, persistSession: false } });
  await ensureDeterministicLocalUser(admin.auth.admin, email, password);
});

test("opens every MVP workspace from one private session", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("邮箱").fill(email);
  await page.getByLabel("密码").fill(password);
  await page.getByRole("button", { name: "登录" }).click();
  await expect(page).toHaveURL(/\/$/);
  const routes: [string, string][] = [
    ["/", "Good"], ["/customers", "Customers"], ["/contacts", "Contacts"], ["/opportunities", "Opportunity Pipeline"],
    ["/interactions", "Interactions"], ["/tasks", "Tasks"], ["/knowledge", "Knowledge Library"], ["/learning", "Learning Journal"],
    ["/insights", "Insights"], ["/reports", "Reports"], ["/reports/daily", "Daily Report"], ["/reports/weekly", "Weekly Review"],
    ["/search", "Global Search"], ["/timeline", "Memory Timeline"], ["/files", "Files & Tags"],
  ];
  for (const [route, heading] of routes) {
    await page.goto(route);
    await expect(page.getByRole("heading", { name: new RegExp(heading) }).first()).toBeVisible();
  }
});
