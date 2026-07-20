import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const css = readFileSync(resolve(process.cwd(), "src/app/globals.css"), "utf8");

const colorTokens = [
  "canvas",
  "paper",
  "ink",
  "muted",
  "border",
  "accent",
  "success",
  "highlight",
  "danger",
];

describe("design tokens", () => {
  it.each(colorTokens)("defines %s for both themes", (token) => {
    const matches = css.match(new RegExp(`--ds-color-${token}:`, "g"));
    expect(matches).toHaveLength(2);
  });

  it("defines the complete spacing, radius, layout, type and motion scales", () => {
    for (let index = 1; index <= 10; index += 1) {
      expect(css).toContain(`--space-${index}:`);
    }
    for (const token of ["none", "control", "floating", "card", "full"]) {
      expect(css).toContain(`--radius-${token}:`);
    }
    for (const token of ["nav", "shell", "reading", "context"]) {
      expect(css).toContain(`--layout-${token}:`);
    }
    for (const token of ["fast", "base", "theme", "reveal", "distance", "easing"]) {
      expect(css).toContain(`--motion-${token}:`);
    }
    expect(css).toContain("--font-heading:");
    expect(css).toContain("--font-interface:");
  });

  it("does not contain glass or shadow styling", () => {
    expect(css).not.toMatch(/backdrop-filter|box-shadow/);
  });
});
