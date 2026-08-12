import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import { throwDomainCommandError } from "@/lib/commands/version-conflict";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
import { CreateContactInputSchema } from "./schema";

const contactCommandRowSchema = z.object({
  id: z.uuid(), full_name: z.string(), version: z.coerce.number().int().positive(), operation_id: z.uuid(),
});
type RpcClient = Pick<SupabaseClient, "rpc">;

export function createContactActions(dependencies: { authClient: Parameters<typeof createCommandContext>[2]; serviceClient: RpcClient }) {
  return {
    async createContact(input: z.input<typeof CreateContactInputSchema>, clientRequestId: string) {
      const value = CreateContactInputSchema.parse(input);
      const context = await createCommandContext("CreateContact", clientRequestId, dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("create_contact", {
        p_verified_user_id: context.user.sub, p_client_request_id: context.clientRequestId,
        p_customer_id: value.customerId, p_full_name: value.fullName, p_preferred_name: value.preferredName ?? null,
        p_department: value.department ?? null, p_position: value.position ?? null, p_email: value.email ?? null,
        p_mobile: value.mobile ?? null, p_wechat: value.wechat ?? null, p_preferred_channel: value.preferredChannel ?? null,
        p_preferred_contact_time: value.preferredContactTime, p_communication_preferences: value.communicationPreferences,
        p_employment_status: value.employmentStatus, p_relationship_status: value.relationshipStatus,
        p_organization_influence: value.organizationInfluence, p_influence_evidence: value.influenceEvidence ?? null,
        p_previous_contact_id: value.previousContactId ?? null, p_data_level: value.dataLevel,
        p_classification_reason: value.classificationReason ?? null,
      });
      if (error) throwDomainCommandError(error, { entityType: "Contact", fallback: "Contact could not be created" });
      const row = contactCommandRowSchema.parse(Array.isArray(data) ? data[0] : data);
      return { id: row.id, fullName: row.full_name, version: row.version, operationId: row.operation_id };
    },
  };
}

async function defaultActions() {
  return createContactActions({ authClient: await createServerClient(), serviceClient: createServiceRoleClient() });
}
export async function createContact(input: z.input<typeof CreateContactInputSchema>, clientRequestId: string) {
  return (await defaultActions()).createContact(input, clientRequestId);
}
