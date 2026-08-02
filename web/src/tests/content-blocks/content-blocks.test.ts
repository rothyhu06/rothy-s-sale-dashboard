import { describe, expect, it } from "vitest";
import { ContentBlockDocumentSchema } from "@/lib/content-blocks/schema";
import { extractPlaintext } from "@/lib/content-blocks/plaintext";

describe("ContentBlockDocument V1", () => {
  it("extracts searchable text from every supported block without HTML", () => {
    const document = ContentBlockDocumentSchema.parse({
      schemaVersion: 1,
      blocks: [
        { id: "p1", type: "paragraph", text: "AI 教学助手" },
        { id: "h1", type: "heading", level: 2, text: "Discovery" },
        { id: "l1", type: "list", style: "unordered", items: ["备课", "教研"] },
        { id: "q1", type: "quote", text: "先理解业务", citation: "Mentor" },
        { id: "c1", type: "callout", tone: "info", text: "Level 3 不外发" },
        { id: "k1", type: "checklist", items: [{ id: "i1", text: "确认预算", checked: false }] },
        { id: "code1", type: "code", language: "sql", code: "select 1" },
        { id: "a1", type: "attachmentReference", attachmentId: "7738b1f3-760a-49b0-bb86-f7f9ed51784c", caption: "方案" },
        { id: "i1", type: "imageReference", attachmentId: "60d74e72-8209-42df-ab94-eace52caf1b3", caption: "架构图" },
      ],
    });

    expect(extractPlaintext(document)).toBe([
      "AI 教学助手", "Discovery", "备课", "教研", "先理解业务", "Mentor",
      "Level 3 不外发", "确认预算", "select 1", "方案", "架构图",
    ].join("\n"));
  });

  it("rejects executable HTML and malformed attachment references", () => {
    expect(() => ContentBlockDocumentSchema.parse({
      schemaVersion: 1,
      blocks: [{ type: "html", html: "<script/>" }],
    })).toThrow();
    expect(() => ContentBlockDocumentSchema.parse({
      schemaVersion: 1,
      blocks: [{ id: "a1", type: "attachmentReference", attachmentId: "not-a-uuid" }],
    })).toThrow();
  });

  it("rejects unknown schema versions and duplicate block ids", () => {
    expect(() => ContentBlockDocumentSchema.parse({ schemaVersion: 2, blocks: [] })).toThrow();
    expect(() => ContentBlockDocumentSchema.parse({
      schemaVersion: 1,
      blocks: [
        { id: "same", type: "paragraph", text: "one" },
        { id: "same", type: "paragraph", text: "two" },
      ],
    })).toThrow("Block ids must be unique");
  });
});
