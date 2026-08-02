import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { createHash, randomUUID } from "node:crypto";
import { identifyAttachmentFile } from "../src/features/attachments/file-identification";
import { requireLocalSupabaseUrl } from "./support/local-supabase";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

test("identifies private Storage bytes and preserves credential-safe deletion", async () => {
  const localUrl = requireLocalSupabaseUrl(supabaseUrl);
  expect(supabaseAnonKey, "Export the local NEXT_PUBLIC_SUPABASE_ANON_KEY").toBeTruthy();
  expect(serviceRoleKey, "Export the local SUPABASE_SERVICE_ROLE_KEY").toBeTruthy();

  const admin = createClient(localUrl.href, serviceRoleKey!, { auth: { autoRefreshToken: false, persistSession: false } });
  const email = `attachment-${randomUUID()}@example.test`;
  const password = `Attachment-${randomUUID()}!`;
  const created = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  expect(created.error).toBeNull();
  const ownerId = created.data.user!.id;
  const userClient = createClient(localUrl.href, supabaseAnonKey!, { auth: { autoRefreshToken: false, persistSession: false } });
  expect((await userClient.auth.signInWithPassword({ email, password })).error).toBeNull();

  async function prepareAndUpload(content: Buffer, filename: string) {
    const prepareReceipt = await admin.rpc("claim_saga_command_receipt", {
      p_verified_user_id: ownerId, p_command_type: "PrepareAttachmentUpload", p_client_request_id: randomUUID(),
    });
    expect(prepareReceipt.error).toBeNull();
    const receipt = prepareReceipt.data[0];
    const prepared = await admin.rpc("prepare_attachment_upload", {
      p_verified_user_id: ownerId,
      p_receipt_id: receipt.id,
      p_operation_id: receipt.operation_id,
      p_original_filename: filename,
      p_safe_filename: filename,
      p_mime_type: "application/pdf",
      p_file_extension: "pdf",
      p_size_bytes: content.byteLength,
      p_file_category: "Document",
      p_data_level: "Level3",
      p_classification_reason: "Local E2E sample",
    });
    expect(prepared.error).toBeNull();
    const attachment = prepared.data[0];
    expect(attachment.object_path).toMatch(new RegExp(`^${ownerId}/${attachment.id}/${filename.replace(".", "\\.")}$`));

    const expiresAt = new Date(Date.now() + 2 * 60 * 60 * 1_000).toISOString();
    const authorized = await admin.rpc("authorize_attachment_upload_credential", {
      p_verified_user_id: ownerId,
      p_operation_id: receipt.operation_id,
      p_attachment_id: attachment.id,
      p_object_path: attachment.object_path,
      p_expires_at: expiresAt,
    });
    expect(authorized.error).toBeNull();
    const credential = await admin.storage.from("business-attachments").createSignedUploadUrl(attachment.object_path, { upsert: false });
    expect(credential.error).toBeNull();
    const uploaded = await userClient.storage.from("business-attachments").uploadToSignedUrl(
      attachment.object_path,
      credential.data!.token,
      new Blob([content.buffer.slice(content.byteOffset, content.byteOffset + content.byteLength) as ArrayBuffer], { type: "application/pdf" }),
      { contentType: "application/pdf" },
    );
    expect(uploaded.error).toBeNull();
    return attachment;
  }

  const spoofed = await prepareAndUpload(Buffer.from("not really a pdf"), "spoofed.pdf");
  const spoofedObject = await admin.storage.from("business-attachments").download(spoofed.object_path);
  expect(spoofedObject.error).toBeNull();
  await expect(identifyAttachmentFile(Buffer.from(await spoofedObject.data!.arrayBuffer()), "pdf")).rejects.toThrow("signature");
  const failedFinalizeReceipt = await admin.rpc("claim_saga_command_receipt", {
    p_verified_user_id: ownerId, p_command_type: "FinalizeAttachmentUpload", p_client_request_id: randomUUID(),
  });
  expect((await admin.rpc("fail_attachment_upload", {
    p_verified_user_id: ownerId,
    p_receipt_id: failedFinalizeReceipt.data[0].id,
    p_operation_id: failedFinalizeReceipt.data[0].operation_id,
    p_attachment_id: spoofed.id,
    p_error_code: "StorageSignatureMismatch",
  })).error).toBeNull();
  expect((await admin.from("attachments").select("storage_status").eq("id", spoofed.id).single()).data?.storage_status).toBe("UploadFailed");

  const validPdf = Buffer.from("%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n");
  const attachment = await prepareAndUpload(validPdf, "valid.pdf");
  const directRead = await userClient.storage.from("business-attachments").download(attachment.object_path);
  expect(directRead.error).not.toBeNull();
  const publicUrl = admin.storage.from("business-attachments").getPublicUrl(attachment.object_path).data.publicUrl;
  expect((await fetch(publicUrl)).ok).toBe(false);

  const verifiedObject = await admin.storage.from("business-attachments").download(attachment.object_path);
  expect(verifiedObject.error).toBeNull();
  const bytes = Buffer.from(await verifiedObject.data!.arrayBuffer());
  await expect(identifyAttachmentFile(bytes, "pdf")).resolves.toMatchObject({ mimeType: "application/pdf" });
  const finalizeReceipt = await admin.rpc("claim_saga_command_receipt", {
    p_verified_user_id: ownerId, p_command_type: "FinalizeAttachmentUpload", p_client_request_id: randomUUID(),
  });
  const finalized = await admin.rpc("finalize_attachment_upload", {
    p_verified_user_id: ownerId,
    p_receipt_id: finalizeReceipt.data[0].id,
    p_operation_id: finalizeReceipt.data[0].operation_id,
    p_attachment_id: attachment.id,
    p_size_bytes: bytes.byteLength,
    p_mime_type: "application/pdf",
    p_checksum_sha256: createHash("sha256").update(bytes).digest("hex"),
  });
  expect(finalized.error).toBeNull();
  expect(finalized.data[0].storage_status).toBe("Available");

  const signedDownload = await admin.storage.from("business-attachments").createSignedUrl(attachment.object_path, 60);
  expect(signedDownload.error).toBeNull();
  expect((await fetch(signedDownload.data!.signedUrl)).ok).toBe(true);

  const deletionReceipt = await admin.rpc("claim_saga_command_receipt", {
    p_verified_user_id: ownerId, p_command_type: "DeleteAttachment", p_client_request_id: randomUUID(),
  });
  const deletionRequested = await admin.rpc("request_attachment_deletion", {
    p_verified_user_id: ownerId,
    p_receipt_id: deletionReceipt.data[0].id,
    p_operation_id: deletionReceipt.data[0].operation_id,
    p_attachment_id: attachment.id,
    p_expected_version: finalized.data[0].version,
  });
  expect(deletionRequested.error).toBeNull();
  expect(deletionRequested.data[0].storage_status).toBe("DeletePending");
  expect(new Date(deletionRequested.data[0].upload_credential_expires_at).getTime()).toBeGreaterThan(Date.now());
  const prematureCompletion = await admin.rpc("complete_attachment_deletion", {
    p_verified_user_id: ownerId,
    p_receipt_id: deletionReceipt.data[0].id,
    p_operation_id: deletionReceipt.data[0].operation_id,
    p_attachment_id: attachment.id,
  });
  expect(prematureCompletion.error?.message).toContain("upload credential is still active");

  const ownerVisible = await userClient.from("attachments").select("id").eq("id", attachment.id);
  expect(ownerVisible.error).toBeNull();
  expect(ownerVisible.data).toEqual([]);
});
