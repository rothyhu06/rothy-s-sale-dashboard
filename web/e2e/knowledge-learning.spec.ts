import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";
import { requireLocalSupabaseUrl } from "./support/local-supabase";
import { ensureDeterministicLocalUser } from "./support/local-test-user";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

async function settledAxe(page: import("@playwright/test").Page) {
  await page.waitForTimeout(400);
  return new AxeBuilder({ page }).analyze();
}

test.describe("Knowledge and Learning journal", () => {
  test.describe.configure({ mode: "serial" });

  const email = "knowledge-learning-e2e@example.test";
  const password = "Knowledge-learning-e2e-only!";
  const suffix = randomUUID().slice(0, 8);
  const knowledgeTitle = `Tencent Cloud AI foundations ${suffix}`;
  const revisedTitle = `${knowledgeTitle} field guide`;
  const learningTitle = `Apply ${knowledgeTitle}`;
  const reviewTitle = `Review ${knowledgeTitle}`;

  test.beforeAll(async () => {
    const localUrl = requireLocalSupabaseUrl(supabaseUrl);
    expect(supabaseAnonKey, "Export the local NEXT_PUBLIC_SUPABASE_ANON_KEY").toBeTruthy();
    expect(serviceRoleKey, "Export the local SUPABASE_SERVICE_ROLE_KEY").toBeTruthy();

    const admin = createClient(localUrl.href, serviceRoleKey!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const user = await ensureDeterministicLocalUser(admin.auth.admin, email, password);
    const tag = await admin.rpc("create_tag", {
      p_verified_user_id: user.id,
      p_client_request_id: randomUUID(),
      p_name: `Tencent AI ${suffix}`,
      p_normalized_name: `tencent ai ${suffix}`,
      p_description: "Knowledge and Learning E2E tag",
      p_data_level: "Level2",
    });
    expect(tag.error).toBeNull();
  });

  test.beforeEach(async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/login");
    await page.getByLabel("邮箱").fill(email);
    await page.getByLabel("密码").fill(password);
    await page.getByRole("button", { name: "登录" }).click();
    await expect(page).toHaveURL(/\/$/);
  });

  test("creates, edits, searches, learns, completes, and reviews a Knowledge note", async ({ page }) => {
    await page.goto("/knowledge");
    await expect(page.getByRole("heading", { name: "Knowledge Library", exact: true })).toBeVisible();
    expect((await settledAxe(page)).violations).toEqual([]);
    await page.getByRole("link", { name: "New Knowledge" }).first().click();

    await page.getByLabel("Title").fill(knowledgeTitle);
    await page.getByLabel("Knowledge type").selectOption("AI Technology");
    await page.getByLabel("Status").selectOption("Learning");
    await page.getByLabel("Confidence").selectOption("Verified");
    await page.getByLabel("Source type").selectOption("Official Doc");
    await page.getByLabel("Source name").fill("Tencent Cloud documentation");
    await page.getByLabel("Source URL").fill("https://cloud.tencent.com/document/product/1772");
    await page.getByLabel("Summary").fill("A reusable account of Tencent Cloud AI capabilities.");
    await page.getByLabel("Knowledge body").fill("Model services, secure deployment, and an education scenario.");
    await page.getByRole("checkbox", { name: new RegExp(`Tencent AI ${suffix}`) }).check();
    await page.getByRole("button", { name: "Create Knowledge" }).click();

    await expect(page).toHaveURL(/\/knowledge\/[0-9a-f-]+$/);
    await expect(page.getByRole("heading", { name: knowledgeTitle })).toBeVisible();
    expect((await settledAxe(page)).violations).toEqual([]);
    await expect(page.getByText("Model services, secure deployment, and an education scenario.")).toBeVisible();
    await expect(page.getByText(`Tencent AI ${suffix}`)).toBeVisible();

    await page.getByRole("link", { name: "Edit Knowledge" }).click();
    await page.getByLabel("Title").fill(revisedTitle);
    await page.getByLabel("Business value").fill("Helps schools evaluate secure AI adoption.");
    await page.getByRole("button", { name: "Save changes" }).click();
    await expect(page.getByRole("heading", { name: revisedTitle })).toBeVisible();
    await expect(page.getByText("Helps schools evaluate secure AI adoption.")).toBeVisible();

    await page.getByRole("link", { name: "Create Learning" }).click();
    await page.getByLabel("Title").fill(learningTitle);
    await page.getByLabel("Learning type").selectOption("Study");
    await page.getByLabel("Status").selectOption("In Progress");
    await page.getByLabel("Objective").fill("Explain the capability in a customer conversation.");
    await page.getByLabel(`Mastery before for ${revisedTitle}`).selectOption("Understand");
    await page.getByRole("button", { name: "Create Learning" }).click();

    await expect(page).toHaveURL(/\/learning\/[0-9a-f-]+$/);
    await expect(page.getByRole("heading", { name: learningTitle })).toBeVisible();
    await page.getByLabel("Learning outcome").selectOption("Applied");
    await page.getByLabel("Mastery after").selectOption("Apply");
    await page.getByLabel("Practice result").fill("Used the explanation in a school AI workshop.");
    await page.getByRole("button", { name: "Complete Learning" }).click();

    await expect(page.getByText("Applied", { exact: true })).toBeVisible();
    await expect(page.getByText("Understand → Apply", { exact: true })).toBeVisible();
    await page.getByRole("link", { name: "Create Review" }).click();
    await page.getByLabel("Title").fill(reviewTitle);
    await page.getByLabel("Objective").fill("Retain the customer-ready explanation.");
    await page.getByRole("button", { name: "Create Review" }).click();

    await expect(page.getByRole("heading", { name: reviewTitle })).toBeVisible();
    await expect(page.getByText("Review of")).toBeVisible();
    await expect(page.getByRole("link", { name: learningTitle })).toBeVisible();
    await expect(page.getByRole("link", { name: revisedTitle })).toBeVisible();

    await page.goto("/knowledge");
    await page.getByLabel("Search Knowledge").fill(suffix);
    await page.getByRole("button", { name: "Search" }).click();
    await expect(page.getByRole("link", { name: new RegExp(revisedTitle) })).toBeVisible();
    await page.getByLabel("Status filter").selectOption("Ready");
    await expect(page.getByText("No Knowledge matches these filters.")).toBeVisible();
    await page.getByLabel("Status filter").selectOption("All");

    const accessibility = await settledAxe(page);
    expect(accessibility.violations).toEqual([]);
  });

  test("keeps Continue Learning usable on mobile and by keyboard", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/learning");
    await expect(page.getByRole("heading", { name: "Learning Journal" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Continue Learning" })).toBeVisible();
    await expect(page.getByRole("link", { name: reviewTitle }).first()).toBeVisible();

    await page.keyboard.press("Tab");
    await expect(page.locator(":focus-visible")).toBeVisible();
    await expect(page.locator("main")).toHaveCSS("padding-left", "20px");
    await page.screenshot({ path: `test-results/knowledge-learning-mobile-${suffix}.png`, fullPage: true });

    const accessibility = await settledAxe(page);
    expect(accessibility.violations).toEqual([]);
  });

  for (const viewport of [
    { name: "tablet", width: 834, height: 1112, expectedLeft: "72px" },
    { name: "desktop", width: 1440, height: 1000, expectedLeft: "224px" },
  ]) {
    test(`keeps the editorial shell responsive on ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto("/knowledge");
      await expect(page.getByRole("heading", { level: 1, name: "Knowledge Library" })).toBeVisible();
      await expect(page.getByRole("navigation", { name: "Studio index" })).toBeVisible();
      await expect(page.locator("main")).toHaveCSS("margin-left", viewport.expectedLeft);
      await page.screenshot({ path: `test-results/knowledge-learning-${viewport.name}-${suffix}.png`, fullPage: true });
    });
  }
});
