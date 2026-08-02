import { beforeEach, describe, expect, it, vi } from "vitest";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const attachmentId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const receiptId = "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f";
const operationId = "60d74e72-8209-42df-ab94-eace52caf1b3";

const { claimSagaCommand, createCommandContext, retrySagaCommand } = vi.hoisted(() => ({
  createCommandContext: vi.fn(),
  claimSagaCommand: vi.fn(),
  retrySagaCommand: vi.fn(),
}));

vi.mock("@/lib/commands/command-context", () => ({ createCommandContext, claimSagaCommand, retrySagaCommand }));

import { createAttachmentActions, validateStoredObject, validateUploadRequest } from "@/features/attachments/actions";

function serviceClient() {
  const rpc = vi.fn().mockResolvedValue({
    data: [{ id: attachmentId, object_path: `${ownerId}/${attachmentId}/proposal.pdf`, storage_status: "Pending", data_level: "Level3" }],
    error: null,
  });
  const createSignedUploadUrl = vi.fn().mockResolvedValue({ data: { signedUrl: "signed", token: "short-lived-token", path: `${ownerId}/${attachmentId}/proposal.pdf` }, error: null });
  return {
    rpc,
    storage: { from: vi.fn().mockReturnValue({ createSignedUploadUrl }) },
    createSignedUploadUrl,
  };
}

describe("attachment upload policy", () => {
  it("accepts an allowed PDF under the 20 MiB application default", () => {
    expect(validateUploadRequest({ originalFilename: "Proposal Final.pdf", mimeType: "application/pdf", sizeBytes: 20 * 1024 * 1024 })).toMatchObject({
      safeFilename: "proposal-final.pdf",
      fileExtension: "pdf",
      fileCategory: "Document",
    });
  });

  it.each([
    [{ originalFilename: "proposal.pdf.exe", mimeType: "application/pdf", sizeBytes: 100 }, "double extension"],
    [{ originalFilename: "active.html", mimeType: "text/html", sizeBytes: 100 }, "file type"],
    [{ originalFilename: "large.pdf", mimeType: "application/pdf", sizeBytes: 20 * 1024 * 1024 + 1 }, "20 MiB"],
  ])("rejects unsafe upload metadata", (input, message) => {
    expect(() => validateUploadRequest(input)).toThrow(new RegExp(message, "i"));
  });
});

describe("finalize object verification", () => {
  it("rejects a Storage object whose actual size or MIME differs from Pending metadata", () => {
    expect(() => validateStoredObject({ declaredMime: "application/pdf", declaredSize: 12, actualMime: "application/pdf", actualSize: 11 })).toThrow("size");
    expect(() => validateStoredObject({ declaredMime: "application/pdf", declaredSize: 12, actualMime: "text/html", actualSize: 12 })).toThrow("MIME");
  });
});

describe("prepareUpload", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    createCommandContext.mockResolvedValue({ user: { sub: ownerId }, commandType: "PrepareAttachmentUpload", clientRequestId: crypto.randomUUID() });
    claimSagaCommand.mockResolvedValue({ receiptId, operationId, status: "Processing", resultReference: null });
  });

  it("injects the verified owner into the service-only prepare RPC and returns a signed upload token", async () => {
    const client = serviceClient();
    const actions = createAttachmentActions({ authClient: {} as never, serviceClient: client as never });

    const result = await actions.prepareUpload({
      originalFilename: "Proposal Final.pdf",
      mimeType: "application/pdf",
      sizeBytes: 1024,
      dataLevel: "Level3",
    }, crypto.randomUUID());

    expect(client.rpc).toHaveBeenCalledWith("prepare_attachment_upload", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_receipt_id: receiptId,
      p_operation_id: operationId,
      p_safe_filename: "proposal-final.pdf",
      p_data_level: "Level3",
    }));
    expect(client.createSignedUploadUrl).toHaveBeenCalledWith(`${ownerId}/${attachmentId}/proposal.pdf`, { upsert: false });
    expect(result).toMatchObject({ attachmentId, uploadToken: "short-lived-token" });
  });
});
