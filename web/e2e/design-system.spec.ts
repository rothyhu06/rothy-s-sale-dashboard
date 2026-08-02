import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test("renders the complete Design System gallery", async ({ page }) => {
  await page.goto("/design-system");
  await expect(page.getByRole("heading", { name: "CSIG Sales OS — Design System" })).toBeVisible();
  for (const section of ["Foundations", "Controls", "Cross-cutting Controls", "Cards", "Memory Timeline", "Growth Progress", "Empty States"]) {
    await expect(page.getByRole("heading", { name: section, exact: true })).toBeVisible();
  }
  await expect(page.getByRole("button", { name: "Ask Your Editor" })).toBeVisible();
  await expect(page.getByText("Demo / Sample Data", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Open command dialog" }).click();
  await expect(page.getByRole("dialog", { name: "Search sample workspace" })).toBeVisible();
});

test("persists manual Day and Night themes", async ({ page }) => {
  await page.goto("/design-system");
  await page.getByRole("button", { name: "Night" }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "night");
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "night");
  await page.getByRole("button", { name: "Day" }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "day");
});

test("has no serious or critical accessibility violations", async ({ page }) => {
  await page.goto("/design-system");
  for (const theme of ["Day", "Night"]) {
    await page.getByRole("button", { name: theme }).click();
    await page.waitForTimeout(450);
    const results = await new AxeBuilder({ page }).analyze();
    expect(results.violations.filter((violation) => ["serious", "critical"].includes(violation.impact ?? ""))).toEqual([]);
  }
});

test("keeps keyboard focus visible and respects reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/design-system");
  await page.keyboard.press("Tab");
  await expect(page.locator(":focus")).toBeVisible();
  const transitionDuration = await page.getByRole("button", { name: "Save note" }).evaluate((element) => getComputedStyle(element).transitionDuration);
  expect(Number.parseFloat(transitionDuration)).toBeLessThanOrEqual(0.001);
});

for (const viewport of [
  { name: "desktop", width: 1440, height: 1024 },
  { name: "tablet", width: 834, height: 1112 },
  { name: "mobile", width: 390, height: 844 },
]) {
  test(`${viewport.name} keeps its intended navigation and captures both themes`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await page.goto("/design-system");
    if (viewport.name === "mobile") {
      await expect(page.getByRole("navigation", { name: "Mobile navigation" })).toBeVisible();
    } else {
      await expect(page.getByRole("navigation", { name: "Studio index" })).toBeVisible();
    }
    for (const theme of ["day", "night"] as const) {
      await page.getByRole("button", { name: theme === "day" ? "Day" : "Night" }).click();
      await page.waitForTimeout(450);
      await page.screenshot({ fullPage: true, path: testInfo.outputPath(`${viewport.name}-${theme}.png`) });
    }
    const hasHorizontalOverflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
    expect(hasHorizontalOverflow).toBe(false);
  });
}
