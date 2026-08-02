import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("server environment boundary", () => {
  it("marks the service-role environment reader as server-only", () => {
    const source = readFileSync(resolve(process.cwd(), "src/lib/env/server.ts"), "utf8");

    expect(source).toMatch(/^import\s+["']server-only["'];/m);
  });
});
