import { z } from "zod";

const blockIdSchema = z.string().trim().min(1).max(100);
const textSchema = z.string().max(100_000);
const captionSchema = z.string().trim().max(500).optional();

const paragraphBlockSchema = z.object({ id: blockIdSchema, type: z.literal("paragraph"), text: textSchema }).strict();
const headingBlockSchema = z.object({ id: blockIdSchema, type: z.literal("heading"), level: z.union([z.literal(1), z.literal(2), z.literal(3)]), text: textSchema }).strict();
const listBlockSchema = z.object({ id: blockIdSchema, type: z.literal("list"), style: z.enum(["ordered", "unordered"]), items: z.array(textSchema).max(500) }).strict();
const quoteBlockSchema = z.object({ id: blockIdSchema, type: z.literal("quote"), text: textSchema, citation: z.string().trim().max(500).optional() }).strict();
const calloutBlockSchema = z.object({ id: blockIdSchema, type: z.literal("callout"), tone: z.enum(["info", "success", "warning"]), text: textSchema }).strict();
const checklistBlockSchema = z.object({
  id: blockIdSchema,
  type: z.literal("checklist"),
  items: z.array(z.object({ id: blockIdSchema, text: textSchema, checked: z.boolean() }).strict()).max(500),
}).strict();
const codeBlockSchema = z.object({ id: blockIdSchema, type: z.literal("code"), language: z.string().trim().max(50).optional(), code: textSchema }).strict();
const attachmentReferenceBlockSchema = z.object({ id: blockIdSchema, type: z.literal("attachmentReference"), attachmentId: z.uuid(), caption: captionSchema }).strict();
const imageReferenceBlockSchema = z.object({ id: blockIdSchema, type: z.literal("imageReference"), attachmentId: z.uuid(), caption: captionSchema }).strict();

export const ContentBlockSchema = z.discriminatedUnion("type", [
  paragraphBlockSchema,
  headingBlockSchema,
  listBlockSchema,
  quoteBlockSchema,
  calloutBlockSchema,
  checklistBlockSchema,
  codeBlockSchema,
  attachmentReferenceBlockSchema,
  imageReferenceBlockSchema,
]);

export const ContentBlockDocumentSchema = z.object({
  schemaVersion: z.literal(1),
  blocks: z.array(ContentBlockSchema).max(1_000),
}).strict().superRefine(({ blocks }, context) => {
  const ids = new Set<string>();
  for (const block of blocks) {
    if (ids.has(block.id)) {
      context.addIssue({ code: "custom", message: "Block ids must be unique", path: ["blocks"] });
      return;
    }
    ids.add(block.id);
  }
});

export type ContentBlock = z.infer<typeof ContentBlockSchema>;
export type ContentBlockDocument = z.infer<typeof ContentBlockDocumentSchema>;
