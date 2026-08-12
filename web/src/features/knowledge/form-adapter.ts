import { ContentBlockDocumentSchema, type ContentBlockDocument } from "@/lib/content-blocks/schema";
import { extractPlaintext } from "@/lib/content-blocks/plaintext";

export function knowledgeBodyToDocument(value: string): ContentBlockDocument {
  const paragraphs = value.split(/\n\s*\n/).map((text) => text.trim()).filter(Boolean);
  return ContentBlockDocumentSchema.parse({
    schemaVersion: 1,
    blocks: paragraphs.map((text, index) => ({ id: `paragraph-${index + 1}`, type: "paragraph", text })),
  });
}

export function documentToKnowledgeBody(document: unknown) {
  return extractPlaintext(ContentBlockDocumentSchema.parse(document)).replace(/\n/g, "\n\n");
}

export function composeKnowledgeDocument(options: {
  body: string;
  originalBody?: string;
  originalDocument?: unknown;
  attachmentIds: string[];
}) {
  const original = options.originalDocument ? ContentBlockDocumentSchema.parse(options.originalDocument) : undefined;
  const document = original && options.body === options.originalBody
    ? structuredClone(original)
    : knowledgeBodyToDocument(options.body);
  const selected = new Set(options.attachmentIds);
  document.blocks = document.blocks.filter((block) =>
    block.type !== "attachmentReference" && block.type !== "imageReference" ? true : selected.has(block.attachmentId));
  const represented = new Set(document.blocks.flatMap((block) =>
    block.type === "attachmentReference" || block.type === "imageReference" ? [block.attachmentId] : []));
  document.blocks.push(...options.attachmentIds.filter((id) => !represented.has(id)).map((attachmentId, index) => ({
    id: `attachment-${index + 1}`, type: "attachmentReference" as const, attachmentId,
  })));
  return ContentBlockDocumentSchema.parse(document);
}
