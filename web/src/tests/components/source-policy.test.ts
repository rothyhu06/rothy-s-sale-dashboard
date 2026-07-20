import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("design-system source policy", () => {
  const directory = resolve(process.cwd(), "src/components/design-system");
  const source = readdirSync(directory)
    .filter((file) => file.endsWith(".tsx"))
    .map((file) => readFileSync(resolve(directory, file), "utf8"))
    .join("\n");

  it("contains no page-specific color or visual-effect escapes", () => {
    expect(source).not.toMatch(/#[0-9a-f]{3,8}\b/i);
    expect(source).not.toMatch(/shadow-|backdrop-|rounded-\[/);
  });
});
