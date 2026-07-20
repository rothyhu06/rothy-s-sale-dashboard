import { describe, expect, it } from "vitest";
import { millisecondsUntilThemeBoundary, resolveTheme } from "@/lib/theme/resolve-theme";

describe("resolveTheme", () => {
  it.each([
    ["auto", 5, "night"],
    ["auto", 6, "day"],
    ["auto", 17, "day"],
    ["auto", 18, "night"],
    ["day", 23, "day"],
    ["night", 9, "night"],
  ] as const)("resolves %s at %s to %s", (preference, hour, expected) => {
    expect(resolveTheme(preference, hour)).toBe(expected);
  });

  it.each([-1, 24, Number.NaN])("rejects invalid hour %s", (hour) => {
    expect(() => resolveTheme("auto", hour)).toThrow("localHour");
  });
});

describe("millisecondsUntilThemeBoundary", () => {
  it("points to 18:00 while in the day theme", () => {
    const now = new Date(2026, 6, 20, 10, 30, 0, 0);
    expect(millisecondsUntilThemeBoundary(now)).toBe(7.5 * 60 * 60 * 1000);
  });

  it("points to the next 06:00 while in the night theme", () => {
    const now = new Date(2026, 6, 20, 21, 0, 0, 0);
    expect(millisecondsUntilThemeBoundary(now)).toBe(9 * 60 * 60 * 1000);
  });
});
