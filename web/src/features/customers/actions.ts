import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import { throwDomainCommandError } from "@/lib/commands/version-conflict";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
import { CreateCustomerInputSchema } from "./schema";

const customerCommandRowSchema = z.object({
  id: z.uuid(), name: z.string(), normalized_name: z.string(), version: z.coerce.number().int().positive(), operation_id: z.uuid(),
});
type RpcClient = Pick<SupabaseClient, "rpc">;

function commandRow(data: unknown) {
  const row = customerCommandRowSchema.parse(Array.isArray(data) ? data[0] : data);
  return { id: row.id, name: row.name, normalizedName: row.normalized_name, version: row.version, operationId: row.operation_id };
}

export function createCustomerActions(dependencies: { authClient: Parameters<typeof createCommandContext>[2]; serviceClient: RpcClient }) {
  return {
    async createCustomer(input: z.input<typeof CreateCustomerInputSchema>, clientRequestId: string) {
      const value = CreateCustomerInputSchema.parse(input);
      const context = await createCommandContext("CreateCustomer", clientRequestId, dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("create_customer", {
        p_verified_user_id: context.user.sub, p_client_request_id: context.clientRequestId,
        p_name: value.name, p_aliases: value.aliases, p_customer_type: value.customerType,
        p_education_segment: value.educationSegment ?? null, p_region: value.region ?? null,
        p_website: value.website ?? null, p_background: value.background ?? null,
        p_business_context: value.businessContext ?? null, p_current_technology: value.currentTechnology ?? null,
        p_current_cloud_provider: value.currentCloudProvider ?? null, p_known_needs: value.knownNeeds ?? null,
        p_internal_assessment: value.internalAssessment ?? null,
        p_student_count_estimate: value.studentCountEstimate ?? null,
        p_faculty_count_estimate: value.facultyCountEstimate ?? null, p_campus_count: value.campusCount ?? null,
        p_organization_stats_as_of: value.organizationStatsAsOf ?? null,
        p_organization_stats_source: value.organizationStatsSource ?? null,
        p_record_status: value.recordStatus, p_data_level: value.dataLevel,
        p_classification_reason: value.classificationReason ?? null,
        p_external_references: value.externalReferences, p_knowledge_links: value.knowledgeLinks,
      });
      if (error) throwDomainCommandError(error, { entityType: "Customer", fallback: "Customer could not be created" });
      return commandRow(data);
    },
  };
}

async function defaultActions() {
  return createCustomerActions({ authClient: await createServerClient(), serviceClient: createServiceRoleClient() });
}
export async function createCustomer(input: z.input<typeof CreateCustomerInputSchema>, clientRequestId: string) {
  return (await defaultActions()).createCustomer(input, clientRequestId);
}
