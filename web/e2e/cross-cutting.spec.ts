import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { createHash, randomUUID } from "node:crypto";
import { requireLocalSupabaseUrl } from "./support/local-supabase";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

test("runs the private Attachment upload and deletion Saga against local Storage", async () => {
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
  const signedIn = await userClient.auth.signInWithPassword({ email, password });
  expect(signedIn.error).toBeNull();

  const prepareReceipt = await admin.rpc("claim_saga_command_receipt", {
    p_verified_user_id: ownerId,
    p_command_type: "PrepareAttachmentUpload",
    p_client_request_id: randomUUID(),
  });
  expect(prepareReceipt.error).toBeNull();
  const receipt = prepareReceipt.data[0];
  const prepared = await admin.rpc("prepare_attachment_upload", {
    p_verified_user_id: ownerId,
    p_receipt_id: receipt.id,
    p_operation_id: receipt.operation_id,
    p_original_filename: "sample.pdf",
    p_safe_filename: "sample.pdf",
    p_mime_type: "application/pdf",
    p_file_extension: "pdf",
    p_size_bytes: 12,
    p_file_category: "Document",
    p_data_level: "Level3",
    p_classification_reason: "Local E2E sample",
  });
  expect(prepared.error).toBeNull();
  const attachment = prepared.data[0];
  expect(attachment.object_path).toMatch(new RegExp(`^${ownerId}/${attachment.id}/sample\\.pdf$`));

  const uploadCredential = await admin.storage.from("business-attachments").createSignedUploadUrl(attachment.object_path, { upsert: false });
  expect(uploadCredential.error).toBeNull();
  const file = new Blob(["hello sales!"], { type: "application/pdf" });
  const uploaded = await userClient.storage.from("business-attachments").uploadToSignedUrl(
    attachment.object_path,
    uploadCredential.data!.token,
    file,
    { contentType: "application/pdf" },
  );
  expect(uploaded.error).toBeNull();

  const directRead = await userClient.storage.from("business-attachments").download(attachment.object_path);
  expect(directRead.error).not.toBeNull();
  const publicUrl = admin.storage.from("business-attachments").getPublicUrl(attachment.object_path).data.publicUrl;
  expect((await fetch(publicUrl)).ok).toBe(false);

  const verifiedObject = await admin.storage.from("business-attachments").download(attachment.object_path);
  expect(verifiedObject.error).toBeNull();
  const bytes = Buffer.from(await verifiedObject.data!.arrayBuffer());
  const finalizeReceipt = await admin.rpc("claim_saga_command_receipt", {
    p_verified_user_id: ownerId,
    p_command_type: "FinalizeAttachmentUpload",
    p_client_request_id: randomUUID(),
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
    p_verified_user_id: ownerId,
    p_command_type: "DeleteAttachment",
    p_client_request_id: randomUUID(),
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
  expect((await admin.storage.from("business-attachments").remove([attachment.object_path])).error).toBeNull();
  const deleted = await admin.rpc("complete_attachment_deletion", {
    p_verified_user_id: ownerId,
    p_receipt_id: deletionReceipt.data[0].id,
    p_operation_id: deletionReceipt.data[0].operation_id,
    p_attachment_id: attachment.id,
  });
  expect(deleted.error).toBeNull();

  const metadata = await admin.from("attachments").select("storage_status, deleted_at, storage_deleted_at").eq("id", attachment.id).single();
  expect(metadata.error).toBeNull();
  expect(metadata.data).toMatchObject({ storage_status: "Deleted" });
  expect(metadata.data!.deleted_at).toBeTruthy();
  expect(metadata.data!.storage_deleted_at).toBeTruthy();
});
