import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  globalSetup: "./e2e/global-setup.ts",
  fullyParallel: true,
  use: {
    baseURL: "http://127.0.0.1:3217",
    trace: "on-first-retry",
  },
  projects: [{ name: "chrome", use: { ...devices["Desktop Chrome"], channel: "chrome" } }],
  webServer: {
    command: "pnpm exec next dev --port 3217 --hostname 127.0.0.1",
    url: "http://127.0.0.1:3217",
    reuseExistingServer: false,
  },
});
