import { describe, expect, it } from "vitest";
import { knowledgeBodyToDocument, documentToKnowledgeBody, composeKnowledgeDocument } from "@/features/knowledge/form-adapter";

describe("Knowledge textarea ContentBlock adapter", () => {
  it("writes textarea content into the authoritative V1 envelope", () => {
    const document = knowledgeBodyToDocument("First paragraph\n\nSecond paragraph");
    expect(document).toEqual({
      schemaVersion: 1,
      blocks: [
        { id: "paragraph-1", type: "paragraph", text: "First paragraph" },
        { id: "paragraph-2", type: "paragraph", text: "Second paragraph" },
      ],
    });
    expect(documentToKnowledgeBody(document)).toBe("First paragraph\n\nSecond paragraph");
  });

  it("preserves exact structured blocks and selected reference metadata when body text is untouched", () => {
    const attachmentId = crypto.randomUUID();
    const original = { schemaVersion: 1 as const, blocks: [
      { id: "heading-stable", type: "heading" as const, level: 2 as const, text: "Structured" },
      { id: "image-stable", type: "imageReference" as const, attachmentId, caption: "Exact caption" },
    ] };
    expect(composeKnowledgeDocument({ body: "Structured\n\nExact caption", originalBody: "Structured\n\nExact caption", originalDocument: original, attachmentIds: [attachmentId] })).toEqual(original);
  });

  it("refuses to flatten edited structured body text without explicit confirmation", () => {
    expect(() => composeKnowledgeDocument({
      body: "Changed",
      originalBody: "Before",
      originalDocument: { schemaVersion: 1, blocks: [{ id: "heading", type: "heading", level: 2, text: "Before" }] },
      attachmentIds: [],
      confirmStructureConversion: false,
    })).toThrow("确认转换");
  });

  it("converts edited structured body only after confirmation and retains selected image metadata", () => {
    const attachmentId = crypto.randomUUID();
    const result = composeKnowledgeDocument({
      body: "Changed",
      originalBody: "Before\n\nExact caption",
      originalDocument: { schemaVersion: 1, blocks: [
        { id: "heading", type: "heading", level: 2, text: "Before" },
        { id: "image-stable", type: "imageReference", attachmentId, caption: "Exact caption" },
      ] },
      attachmentIds: [attachmentId],
      confirmStructureConversion: true,
    });
    expect(result.blocks).toEqual([
      { id: "paragraph-1", type: "paragraph", text: "Changed" },
      { id: "image-stable", type: "imageReference", attachmentId, caption: "Exact caption" },
    ]);
  });
});
