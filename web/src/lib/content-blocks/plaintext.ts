import { ContentBlockDocumentSchema, type ContentBlock, type ContentBlockDocument } from "./schema";

function blockText(block: ContentBlock): string[] {
  switch (block.type) {
    case "paragraph":
    case "heading":
    case "callout": return [block.text];
    case "list": return block.items;
    case "quote": return [block.text, block.citation ?? ""];
    case "checklist": return block.items.map((item) => item.text);
    case "code": return [block.code];
    case "attachmentReference":
    case "imageReference": return [block.caption ?? ""];
  }
}

export function extractPlaintext(document: ContentBlockDocument): string {
  const parsed = ContentBlockDocumentSchema.parse(document);
  return parsed.blocks.flatMap(blockText).map((value) => value.trim()).filter(Boolean).join("\n");
}
