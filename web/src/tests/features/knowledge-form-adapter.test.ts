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

  it("converts edited body text and retains selected references", () => {
    const attachmentId = crypto.randomUUID();
    const result = composeKnowledgeDocument({ body: "Changed", originalBody: "Before", originalDocument: { schemaVersion: 1, blocks: [] }, attachmentIds: [attachmentId] });
    expect(result.blocks).toEqual([
      { id: "paragraph-1", type: "paragraph", text: "Changed" },
      { id: "attachment-1", type: "attachmentReference", attachmentId },
    ]);
  });
});
