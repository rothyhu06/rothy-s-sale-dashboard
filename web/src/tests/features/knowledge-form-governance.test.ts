import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("Knowledge form Design System governance", () => {
  const source = readFileSync(resolve(process.cwd(), "src/features/knowledge/components/knowledge-form.tsx"), "utf8");

  it("uses governed visual tokens and describes structured conversion accurately", () => {
    expect(source).not.toMatch(/rounded-md|border-warning/);
    expect(source).toContain("radius-card border border-border");
    expect(source).toContain("转换会将标题、列表、代码与提示框等结构化文本块替换为纯文本段落；已选附件与图片引用块及其说明文字会保留。");
    expect(source).not.toContain("图片类型与说明文字");
  });
});
