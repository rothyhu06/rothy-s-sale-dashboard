import { describe, expect, it, vi } from "vitest";
import { validateAttachmentReferences } from "@/lib/content-blocks/attachment-references";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const documentId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const imageId = "60d74e72-8209-42df-ab94-eace52caf1b3";

const document = {
  schemaVersion: 1 as const,
  blocks: [
    { id: "a1", type: "attachmentReference" as const, attachmentId: documentId },
    { id: "i1", type: "imageReference" as const, attachmentId: imageId },
  ],
};

describe("Attachment Reference Validator", () => {
  it("returns unique references and escalates to the maximum data level", async () => {
    const findByIds = vi.fn().mockResolvedValue([
      { id: documentId, owner_id: ownerId, storage_status: "Available", deleted_at: null, file_category: "Document", data_level: "Level2" },
      { id: imageId, owner_id: ownerId, storage_status: "Available", deleted_at: null, file_category: "Image", data_level: "Level3" },
    ]);
    await expect(validateAttachmentReferences(document, { ownerId, baseDataLevel: "Level1", repository: { findByIds } })).resolves.toEqual({
      attachmentIds: [documentId, imageId],
      imageAttachmentIds: [imageId],
      effectiveDataLevel: "Level3",
    });
    expect(findByIds).toHaveBeenCalledWith(ownerId, [documentId, imageId]);
  });

  it.each([
    [[], "missing"],
    [[{ id: documentId, owner_id: "00000000-0000-4000-8000-000000000099", storage_status: "Available", deleted_at: null, file_category: "Document", data_level: "Level2" }], "owner"],
    [[{ id: documentId, owner_id: ownerId, storage_status: "Deleted", deleted_at: new Date().toISOString(), file_category: "Document", data_level: "Level2" }], "available"],
  ])("rejects unavailable or foreign references", async (rows, message) => {
    await expect(validateAttachmentReferences({ schemaVersion: 1, blocks: [{ id: "a1", type: "attachmentReference", attachmentId: documentId }] }, {
      ownerId, baseDataLevel: "Level1", repository: { findByIds: vi.fn().mockResolvedValue(rows) },
    })).rejects.toThrow(new RegExp(message, "i"));
  });

  it("requires imageReference to target an image", async () => {
    await expect(validateAttachmentReferences({ schemaVersion: 1, blocks: [{ id: "i1", type: "imageReference", attachmentId: imageId }] }, {
      ownerId,
      baseDataLevel: "Level1",
      repository: { findByIds: vi.fn().mockResolvedValue([{ id: imageId, owner_id: ownerId, storage_status: "Available", deleted_at: null, file_category: "Document", data_level: "Level2" }]) },
    })).rejects.toThrow("image");
  });
});
