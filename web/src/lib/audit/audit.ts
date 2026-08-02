import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";

const auditEntrySchema = z.object({
  action: z.string().min(1).max(100),
  entityType: z.string().min(1).max(100),
  entityId: z.uuid().nullable().optional(),
  requestId: z.uuid().nullable().optional(),
  clientRequestId: z.uuid().nullable().optional(),
  operationId: z.uuid().nullable().optional(),
  changedFields: z.array(z.string().min(1).max(100)).default([]),
  metadata: z.record(z.string(), z.union([z.string(), z.number(), z.boolean(), z.null()])).default({}),
  requestIpHash: z.string().max(256).nullable().optional(),
  userAgent: z.string().max(1024).nullable().optional(),
  result: z.string().min(1).max(50).default("Success"),
  errorCode: z.string().max(100).nullable().optional(),
});

export type AuditEntry = z.input<typeof auditEntrySchema>;

type AuditClient = Pick<SupabaseClient, "rpc">;

export async function writeAuditLog(entry: AuditEntry, client?: AuditClient) {
  const value = auditEntrySchema.parse(entry);
  const supabase = client ?? (await createServerClient());
  const { data, error } = await supabase.rpc("write_audit_log", {
    p_action: value.action,
    p_entity_type: value.entityType,
    p_entity_id: value.entityId ?? null,
    p_request_id: value.requestId ?? null,
    p_client_request_id: value.clientRequestId ?? null,
    p_operation_id: value.operationId ?? null,
    p_changed_fields: value.changedFields,
    p_metadata: value.metadata,
    p_request_ip_hash: value.requestIpHash ?? null,
    p_user_agent: value.userAgent ?? null,
    p_result: value.result,
    p_error_code: value.errorCode ?? null,
  });

  if (error) {
    throw new Error("Audit log could not be written", { cause: error });
  }

  return data as string;
}
