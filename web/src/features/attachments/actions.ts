import "server-only";

import { createHash } from "node:crypto";
import { z } from "zod";
import { writeAuditLog } from "@/lib/audit/audit";
import { claimSagaCommand, createCommandContext, retrySagaCommand } from "@/lib/commands/command-context";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";

const BUCKET = "business-attachments";
const DEFAULT_MAX_BYTES = 20 * 1024 * 1024;
const SIGNED_DOWNLOAD_SECONDS = 60;

const allowedFiles = {
  pdf: { mime: "application/pdf", category: "Document" },
  docx: { mime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", category: "Document" },
  xlsx: { mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", category: "Document" },
  pptx: { mime: "application/vnd.openxmlformats-officedocument.presentationml.presentation", category: "Document" },
  png: { mime: "image/png", category: "Image" },
  jpg: { mime: "image/jpeg", category: "Image" },
  jpeg: { mime: "image/jpeg", category: "Image" },
  webp: { mime: "image/webp", category: "Image" },
  txt: { mime: "text/plain", category: "Text" },
  md: { mime: "text/markdown", category: "Text" },
  csv: { mime: "text/csv", category: "Data" },
} as const;

const uploadRequestSchema = z.object({
  originalFilename: z.string().trim().min(1).max(255),
  mimeType: z.string().trim().min(1).max(255),
  sizeBytes: z.number().int().nonnegative(),
});

const prepareInputSchema = uploadRequestSchema.extend({
  dataLevel: z.enum(["Level1", "Level2", "Level3"]).default("Level2"),
  classificationReason: z.string().trim().max(1_000).nullable().optional(),
});

const finalizeInputSchema = z.object({ attachmentId: z.uuid() });
const deleteInputSchema = z.object({ attachmentId: z.uuid(), expectedVersion: z.number().int().positive() });
const downloadInputSchema = z.object({ attachmentId: z.uuid(), expiresIn: z.number().int().min(1).max(300).default(SIGNED_DOWNLOAD_SECONDS) });

type RpcResult = Promise<{ data: unknown; error: unknown }>;
type QueryResult = Promise<{ data: unknown; error: unknown }>;
type StorageBucket = {
  createSignedUploadUrl(path: string, options?: { upsert?: boolean }): RpcResult;
  createSignedUrl(path: string, expiresIn: number, options?: { download?: string | boolean }): RpcResult;
  download(path: string): Promise<{ data: Blob | null; error: unknown }>;
  remove(paths: string[]): RpcResult;
  list(path: string, options?: { search?: string; limit?: number }): RpcResult;
};
type AttachmentServiceClient = {
  rpc(name: string, params: Record<string, unknown>): RpcResult;
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): {
        eq(column: string, value: string): { single(): QueryResult };
        single(): QueryResult;
      };
    };
  };
  storage: { from(bucket: string): StorageBucket };
};
type AttachmentDependencies = {
  authClient: Parameters<typeof createCommandContext>[2];
  serviceClient: AttachmentServiceClient;
  auditWriter?: typeof writeAuditLog;
};

const attachmentRowSchema = z.object({
  id: z.uuid(),
  object_path: z.string().min(1),
  original_filename: z.string().optional(),
  mime_type: z.string().optional(),
  size_bytes: z.coerce.number().int().nonnegative().optional(),
  storage_status: z.enum(["Pending", "Available", "UploadFailed", "DeletePending", "DeleteFailed", "Deleted"]),
  data_level: z.enum(["Level1", "Level2", "Level3"]).optional(),
  version: z.coerce.number().int().positive().optional(),
});

function rowFrom(data: unknown) {
  return attachmentRowSchema.parse(Array.isArray(data) ? data[0] : data);
}

function dataError(error: unknown, message: string): never {
  throw new Error(message, { cause: error });
}

function safeBaseName(value: string) {
  const normalized = value.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  const ascii = normalized.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return ascii.slice(0, 150) || "file";
}

export function validateUploadRequest(input: z.input<typeof uploadRequestSchema>) {
  const value = uploadRequestSchema.parse(input);
  if (value.sizeBytes > DEFAULT_MAX_BYTES) throw new Error("File exceeds the 20 MiB application default");

  const parts = value.originalFilename.toLowerCase().split(".");
  if (parts.length < 2) throw new Error("Allowed file type required");
  const extension = parts.at(-1) ?? "";
  if (parts.slice(0, -1).some((part) => part in allowedFiles)) throw new Error("Unsafe double extension");
  if (!(extension in allowedFiles)) throw new Error("File type is not allowed");

  const policy = allowedFiles[extension as keyof typeof allowedFiles];
  if (value.mimeType.toLowerCase() !== policy.mime) throw new Error("File type and MIME type do not match");
  const base = value.originalFilename.slice(0, -(extension.length + 1));

  return {
    ...value,
    fileExtension: extension,
    fileCategory: policy.category,
    safeFilename: `${safeBaseName(base)}.${extension}`,
  };
}

export function validateStoredObject(input: {
  declaredMime: string;
  declaredSize: number;
  actualMime: string;
  actualSize: number;
}) {
  if (input.actualSize !== input.declaredSize) throw new Error("Uploaded object size does not match Pending metadata");
  if (input.actualMime !== input.declaredMime) throw new Error("Uploaded object MIME does not match Pending metadata");
}

export function createAttachmentActions(dependencies: AttachmentDependencies) {
  const bucket = dependencies.serviceClient.storage.from(BUCKET);
  const sagaClient = dependencies.serviceClient as unknown as NonNullable<Parameters<typeof claimSagaCommand>[1]>;
  const auditWriter = dependencies.auditWriter ?? writeAuditLog;

  async function signedUpload(attachmentId: string, objectPath: string) {
    const { data, error } = await bucket.createSignedUploadUrl(objectPath, { upsert: false });
    if (error) dataError(error, "Signed upload credential could not be created");
    const signed = z.object({ token: z.string().min(1) }).parse(data);
    return { attachmentId, objectPath, uploadToken: signed.token };
  }

  return {
    async prepareUpload(input: z.input<typeof prepareInputSchema>, clientRequestId: string) {
      const value = prepareInputSchema.parse(input);
      const file = validateUploadRequest(value);
      const context = await createCommandContext("PrepareAttachmentUpload", clientRequestId, dependencies.authClient);
      const receipt = await claimSagaCommand(context, sagaClient);

      if (receipt.status === "Completed") {
        const replay = z.object({ attachmentId: z.uuid(), objectPath: z.string().min(1) }).parse(receipt.resultReference);
        return signedUpload(replay.attachmentId, replay.objectPath);
      }
      if (receipt.status === "Failed") throw new Error("Failed upload preparation requires a new request id");

      const { data, error } = await dependencies.serviceClient.rpc("prepare_attachment_upload", {
        p_verified_user_id: context.user.sub,
        p_receipt_id: receipt.receiptId,
        p_operation_id: receipt.operationId,
        p_original_filename: value.originalFilename.trim(),
        p_safe_filename: file.safeFilename,
        p_mime_type: file.mimeType.toLowerCase(),
        p_file_extension: file.fileExtension,
        p_size_bytes: file.sizeBytes,
        p_file_category: file.fileCategory,
        p_data_level: value.dataLevel,
        p_classification_reason: value.classificationReason ?? null,
      });
      if (error) dataError(error, "Pending attachment could not be prepared");
      const attachment = rowFrom(data);
      return signedUpload(attachment.id, attachment.object_path);
    },

    async finalizeUpload(input: z.input<typeof finalizeInputSchema>, clientRequestId: string) {
      const value = finalizeInputSchema.parse(input);
      const context = await createCommandContext("FinalizeAttachmentUpload", clientRequestId, dependencies.authClient);
      const receipt = await claimSagaCommand(context, sagaClient);
      if (receipt.status === "Completed") return receipt.resultReference;
      if (receipt.status === "Failed") throw new Error("Failed upload finalization requires a new upload");

      const query = dependencies.serviceClient.from("attachments").select("id, object_path, mime_type, size_bytes, storage_status, data_level, version");
      const { data: metadata, error: metadataError } = await query.eq("owner_id", context.user.sub).eq("id", value.attachmentId).single();
      if (metadataError) dataError(metadataError, "Pending attachment metadata could not be read");
      const attachment = rowFrom(metadata);
      const { data: object, error: objectError } = await bucket.download(attachment.object_path);
      if (objectError || !object) {
        await dependencies.serviceClient.rpc("fail_attachment_upload", {
          p_verified_user_id: context.user.sub, p_receipt_id: receipt.receiptId,
          p_operation_id: receipt.operationId, p_attachment_id: attachment.id, p_error_code: "StorageObjectMissing",
        });
        dataError(objectError, "Uploaded Storage object could not be verified");
      }
      const bytes = Buffer.from(await object.arrayBuffer());
      const actualMime = object.type || attachment.mime_type || "";
      try {
        validateStoredObject({
          declaredMime: attachment.mime_type ?? "",
          declaredSize: attachment.size_bytes ?? -1,
          actualMime,
          actualSize: bytes.byteLength,
        });
      } catch (verificationError) {
        await dependencies.serviceClient.rpc("fail_attachment_upload", {
          p_verified_user_id: context.user.sub, p_receipt_id: receipt.receiptId,
          p_operation_id: receipt.operationId, p_attachment_id: attachment.id, p_error_code: "StorageMetadataMismatch",
        });
        throw verificationError;
      }
      const checksum = createHash("sha256").update(bytes).digest("hex");
      const { data, error } = await dependencies.serviceClient.rpc("finalize_attachment_upload", {
        p_verified_user_id: context.user.sub, p_receipt_id: receipt.receiptId,
        p_operation_id: receipt.operationId, p_attachment_id: attachment.id,
        p_size_bytes: bytes.byteLength, p_mime_type: actualMime, p_checksum_sha256: checksum,
      });
      if (error) dataError(error, "Attachment upload could not be finalized");
      return rowFrom(data);
    },

    async requestAttachmentDeletion(input: z.input<typeof deleteInputSchema>, clientRequestId: string) {
      const value = deleteInputSchema.parse(input);
      const context = await createCommandContext("DeleteAttachment", clientRequestId, dependencies.authClient);
      let receipt = await claimSagaCommand(context, sagaClient);
      if (receipt.status === "Completed") return receipt.resultReference;
      if (receipt.status === "Failed") receipt = await retrySagaCommand(context, receipt, sagaClient);

      const { data, error } = await dependencies.serviceClient.rpc("request_attachment_deletion", {
        p_verified_user_id: context.user.sub, p_receipt_id: receipt.receiptId,
        p_operation_id: receipt.operationId, p_attachment_id: value.attachmentId,
        p_expected_version: value.expectedVersion,
      });
      if (error) dataError(error, "Attachment deletion could not be requested");
      const attachment = rowFrom(data);
      const { error: removeError } = await bucket.remove([attachment.object_path]);
      const directory = attachment.object_path.slice(0, attachment.object_path.lastIndexOf("/"));
      const filename = attachment.object_path.slice(attachment.object_path.lastIndexOf("/") + 1);
      const { data: remaining, error: listError } = await bucket.list(directory, { search: filename, limit: 10 });
      const stillExists = z.array(z.object({ name: z.string() })).catch([]).parse(remaining).some((entry) => entry.name === filename);
      if (removeError || listError || stillExists) {
        await dependencies.serviceClient.rpc("fail_attachment_deletion", {
          p_verified_user_id: context.user.sub, p_receipt_id: receipt.receiptId,
          p_operation_id: receipt.operationId, p_attachment_id: attachment.id, p_error_code: "StorageDeleteUnconfirmed",
        });
        dataError(removeError ?? listError ?? new Error("Object still exists"), "Storage deletion could not be confirmed");
      }
      const completion = await dependencies.serviceClient.rpc("complete_attachment_deletion", {
        p_verified_user_id: context.user.sub, p_receipt_id: receipt.receiptId,
        p_operation_id: receipt.operationId, p_attachment_id: attachment.id,
      });
      if (completion.error) dataError(completion.error, "Attachment deletion could not be finalized");
      return { attachmentId: attachment.id, storageStatus: "Deleted" as const };
    },

    async createDownloadUrl(input: z.input<typeof downloadInputSchema>) {
      const value = downloadInputSchema.parse(input);
      const context = await createCommandContext("AccessAttachment", crypto.randomUUID(), dependencies.authClient);
      const query = dependencies.serviceClient.from("attachments").select("id, object_path, original_filename, mime_type, size_bytes, storage_status, data_level, version");
      const { data, error } = await query.eq("owner_id", context.user.sub).eq("id", value.attachmentId).single();
      if (error) dataError(error, "Attachment metadata could not be read");
      const attachment = rowFrom(data);
      if (attachment.storage_status !== "Available") throw new Error("Attachment is not available");
      const signed = await bucket.createSignedUrl(attachment.object_path, value.expiresIn, { download: attachment.original_filename ?? true });
      if (signed.error) dataError(signed.error, "Signed download URL could not be created");
      if (attachment.data_level === "Level3") {
        await auditWriter(context, {
          action: "SensitiveAttachmentAccessed",
          entityType: "Attachment",
          entityId: attachment.id,
          metadata: { dataLevel: "Level3", expiresInSeconds: value.expiresIn },
        }, sagaClient);
      }
      return z.object({ signedUrl: z.string().url() }).parse(signed.data).signedUrl;
    },
  };
}

async function defaultActions() {
  return createAttachmentActions({
    authClient: await createServerClient(),
    serviceClient: createServiceRoleClient() as unknown as AttachmentServiceClient,
  });
}

export async function prepareUpload(input: z.input<typeof prepareInputSchema>, clientRequestId: string) {
  return (await defaultActions()).prepareUpload(input, clientRequestId);
}
export async function finalizeUpload(input: z.input<typeof finalizeInputSchema>, clientRequestId: string) {
  return (await defaultActions()).finalizeUpload(input, clientRequestId);
}
export async function requestAttachmentDeletion(input: z.input<typeof deleteInputSchema>, clientRequestId: string) {
  return (await defaultActions()).requestAttachmentDeletion(input, clientRequestId);
}
export async function createAttachmentDownloadUrl(input: z.input<typeof downloadInputSchema>) {
  return (await defaultActions()).createDownloadUrl(input);
}
