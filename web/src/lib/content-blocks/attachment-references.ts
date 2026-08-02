import "server-only";

import { z } from "zod";
import { ContentBlockDocumentSchema, type ContentBlockDocument } from "./schema";

const levelSchema = z.enum(["Level1", "Level2", "Level3"]);
const attachmentRowSchema = z.object({
  id: z.uuid(),
  owner_id: z.uuid(),
  storage_status: z.enum(["Pending", "Available", "UploadFailed", "DeletePending", "DeleteFailed", "Deleted"]),
  deleted_at: z.string().nullable(),
  file_category: z.enum(["Document", "Image", "Text", "Data", "Other"]),
  data_level: levelSchema,
});

export type AttachmentReferenceRepository = {
  findByIds(ownerId: string, ids: string[]): Promise<unknown[]>;
};

const rank = { Level1: 1, Level2: 2, Level3: 3 } as const;

export async function validateAttachmentReferences(
  document: ContentBlockDocument,
  options: { ownerId: string; baseDataLevel: z.infer<typeof levelSchema>; repository: AttachmentReferenceRepository },
) {
  const ownerId = z.uuid().parse(options.ownerId);
  const baseDataLevel = levelSchema.parse(options.baseDataLevel);
  const parsed = ContentBlockDocumentSchema.parse(document);
  const referenceBlocks = parsed.blocks.filter((block) => block.type === "attachmentReference" || block.type === "imageReference");
  const attachmentIds = [...new Set(referenceBlocks.map((block) => block.attachmentId))];
  const imageAttachmentIds = [...new Set(referenceBlocks.filter((block) => block.type === "imageReference").map((block) => block.attachmentId))];
  if (!attachmentIds.length) return { attachmentIds, imageAttachmentIds, effectiveDataLevel: baseDataLevel };

  const rows = z.array(attachmentRowSchema).parse(await options.repository.findByIds(ownerId, attachmentIds));
  const byId = new Map(rows.map((row) => [row.id, row]));
  for (const id of attachmentIds) {
    const row = byId.get(id);
    if (!row) throw new Error(`Attachment reference is missing: ${id}`);
    if (row.owner_id !== ownerId) throw new Error("Attachment reference belongs to another owner");
    if (row.storage_status !== "Available" || row.deleted_at !== null) throw new Error("Attachment reference is not available");
  }
  for (const id of imageAttachmentIds) {
    if (byId.get(id)?.file_category !== "Image") throw new Error("Image reference must target an image attachment");
  }
  const effectiveDataLevel = rows.reduce((current, row) => rank[row.data_level] > rank[current] ? row.data_level : current, baseDataLevel);
  return { attachmentIds, imageAttachmentIds, effectiveDataLevel };
}
