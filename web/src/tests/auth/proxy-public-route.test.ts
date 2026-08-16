import { describe, expect, it } from "vitest";
import { isDatabaseIndependentPublicRoute } from "@/proxy";

describe("database-independent public routes", () => {
  it("keeps the sample-only Design System available without Supabase", () => {
    expect(isDatabaseIndependentPublicRoute("/design-system")).toBe(true);
  });

  it("does not bypass authentication for login or business routes", () => {
    expect(isDatabaseIndependentPublicRoute("/login")).toBe(false);
    expect(isDatabaseIndependentPublicRoute("/customers")).toBe(false);
  });
});
