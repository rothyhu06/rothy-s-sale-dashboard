import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";

const EntityTypeSchema = z.enum(["Customer", "Contact"]);
const PreviewInputSchema = z.object({ entityType: EntityTypeSchema, survivorId: z.uuid(), duplicateId: z.uuid() }).strict();
const PreviewRowSchema = z.object({
  preview_id: z.uuid(), preview_token: z.string().min(20), plan_hash: z.string().regex(/^[a-f0-9]{64}$/), expires_at: z.string(),
  entity_type: EntityTypeSchema, survivor_id: z.uuid(), duplicate_id: z.uuid(), survivor_version: z.number().int().positive(),
  duplicate_version: z.number().int().positive(), plan: z.record(z.string(), z.unknown()),
});
const ExecuteInputSchema = z.object({
  previewId: z.uuid(), previewToken: z.string().min(20), planHash: z.string().regex(/^[a-f0-9]{64}$/),
  survivorVersion: z.number().int().positive(), duplicateVersion: z.number().int().positive(), clientRequestId: z.uuid(),
  entityType: EntityTypeSchema.optional(), survivorId: z.uuid().optional(), duplicateId: z.uuid().optional(), expiresAt: z.string().optional(), plan: z.unknown().optional(),
}).strict();
type RpcClient = Pick<SupabaseClient, "rpc">;

function mapPreview(data: unknown) {
  const row = PreviewRowSchema.parse(Array.isArray(data) ? data[0] : data);
  return { previewId: row.preview_id, previewToken: row.preview_token, planHash: row.plan_hash, expiresAt: row.expires_at,
    entityType: row.entity_type, survivorId: row.survivor_id, duplicateId: row.duplicate_id,
    survivorVersion: row.survivor_version, duplicateVersion: row.duplicate_version, plan: row.plan };
}

export function createMergeActions(dependencies: { authClient: Parameters<typeof createCommandContext>[2]; serviceClient: RpcClient }) {
  return {
    async previewMerge(input: z.input<typeof PreviewInputSchema>) {
      const value = PreviewInputSchema.parse(input);
      const context = await createCommandContext("PreviewEntityMerge", crypto.randomUUID(), dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("preview_entity_merge", {
        p_verified_user_id: context.user.sub, p_entity_type: value.entityType,
        p_survivor_id: value.survivorId, p_duplicate_id: value.duplicateId,
      });
      if (error) throw new Error("Merge preview could not be created", { cause: error });
      return mapPreview(data);
    },
    async executeMerge(input: z.input<typeof ExecuteInputSchema>) {
      const value = ExecuteInputSchema.parse(input);
      const context = await createCommandContext("ExecuteEntityMerge", value.clientRequestId, dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("execute_entity_merge", {
        p_verified_user_id: context.user.sub, p_client_request_id: context.clientRequestId,
        p_preview_id: value.previewId, p_preview_token: value.previewToken, p_plan_hash: value.planHash,
        p_survivor_version: value.survivorVersion, p_duplicate_version: value.duplicateVersion,
      });
      if (error) throw new Error("Merge could not be executed", { cause: error });
      return data;
    },
  };
}
async function defaultActions() { return createMergeActions({ authClient: await createServerClient(), serviceClient: createServiceRoleClient() }); }
export async function previewMerge(input: z.input<typeof PreviewInputSchema>) { return (await defaultActions()).previewMerge(input); }
export async function executeMerge(input: z.input<typeof ExecuteInputSchema>) { return (await defaultActions()).executeMerge(input); }
