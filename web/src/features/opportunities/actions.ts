import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import { throwDomainCommandError } from "@/lib/commands/version-conflict";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
import { CreateOpportunityInputSchema, OpportunityOutcomeInputSchema, ReopenOpportunityInputSchema, TransitionOpportunityInputSchema } from "./schema";

type RpcClient = Pick<SupabaseClient, "rpc">;
const commandRowSchema = z.record(z.string(), z.unknown()).and(z.object({ operation_id: z.uuid() }));
function commandRow(data: unknown) { return commandRowSchema.parse(Array.isArray(data) ? data[0] : data); }

export function createOpportunityActions(dependencies: { authClient: Parameters<typeof createCommandContext>[2]; serviceClient: RpcClient }) {
  async function context(command: string, requestId: string) { return createCommandContext(command, requestId, dependencies.authClient); }
  async function invoke(command: string, rpc: string, requestId: string, params: Record<string, unknown>) {
    const ctx = await context(command, requestId);
    const { data, error } = await dependencies.serviceClient.rpc(rpc, { p_verified_user_id: ctx.user.sub, p_client_request_id: ctx.clientRequestId, ...params });
    if (error) throwDomainCommandError(error, { entityType: "Opportunity", expectedVersion: typeof params.p_expected_version === "number" ? params.p_expected_version : undefined, fallback: "Opportunity command could not be completed" });
    return commandRow(data);
  }
  return {
    async createOpportunity(input: z.input<typeof CreateOpportunityInputSchema>, requestId: string) {
      const v = CreateOpportunityInputSchema.parse(input);
      return invoke("CreateOpportunity", "create_opportunity", requestId, {
        p_customer_id: v.customerId, p_parent_opportunity_id: v.parentOpportunityId ?? null, p_name: v.name,
        p_opportunity_type: v.opportunityType, p_source_type: v.sourceType ?? null, p_source_contact_id: v.sourceContactId ?? null,
        p_scenario: v.scenario ?? null, p_customer_need: v.customerNeed ?? null, p_desired_outcome: v.desiredOutcome ?? null,
        p_solution_direction: v.solutionDirection ?? null, p_constraints: v.constraints ?? null,
        p_estimated_amount: v.estimatedAmount ?? null, p_currency: v.currency ?? null, p_amount_basis: v.amountBasis ?? null,
        p_amount_as_of: v.amountAsOf ?? null, p_expected_decision_date: v.expectedDecisionDate ?? null,
        p_initial_stage: "Lead", p_changed_source: "Manual", p_contact_roles: v.contactRoles,
      });
    },
    async transitionOpportunity(input: z.input<typeof TransitionOpportunityInputSchema>, requestId: string) {
      const v = TransitionOpportunityInputSchema.parse(input);
      return invoke("TransitionOpportunity", "transition_opportunity", requestId, {
        p_opportunity_id: v.opportunityId, p_expected_version: v.expectedVersion,
        p_expected_current_stage_history_id: v.expectedCurrentStageHistoryId, p_to_stage: v.toStage,
        p_changed_source: v.changedSource, p_reason: v.reason ?? null,
      });
    },
    async recordOutcome(input: z.input<typeof OpportunityOutcomeInputSchema>, requestId: string) {
      const v = OpportunityOutcomeInputSchema.parse(input);
      return invoke("RecordOpportunityOutcome", "record_opportunity_outcome", requestId, {
        p_opportunity_id: v.opportunityId, p_expected_version: v.expectedVersion,
        p_expected_current_stage_history_id: v.expectedCurrentStageHistoryId, p_outcome_type: v.outcomeType,
        p_final_amount: v.finalAmount, p_currency: v.currency, p_decision_date: v.decisionDate, p_reason: v.reason,
        p_competitor: v.competitor ?? null, p_decision_factors: v.decisionFactors,
        p_customer_value: v.customerValue ?? null, p_lessons: v.lessons ?? null,
        p_review_completed_at: v.reviewCompletedAt ?? null,
      });
    },
    async reopenOpportunity(input: z.input<typeof ReopenOpportunityInputSchema>, requestId: string) {
      const v = ReopenOpportunityInputSchema.parse(input);
      return invoke("ReopenOpportunity", "reopen_opportunity", requestId, {
        p_opportunity_id: v.opportunityId, p_expected_version: v.expectedVersion,
        p_expected_current_stage_history_id: v.expectedCurrentStageHistoryId, p_to_stage: v.toStage,
        p_changed_source: v.changedSource, p_reason: v.reason,
      });
    },
  };
}

async function defaults() { return createOpportunityActions({ authClient: await createServerClient(), serviceClient: createServiceRoleClient() }); }
export async function createOpportunity(input: z.input<typeof CreateOpportunityInputSchema>, id: string) { return (await defaults()).createOpportunity(input, id); }
export async function transitionOpportunity(input: z.input<typeof TransitionOpportunityInputSchema>, id: string) { return (await defaults()).transitionOpportunity(input, id); }
export async function recordOpportunityOutcome(input: z.input<typeof OpportunityOutcomeInputSchema>, id: string) { return (await defaults()).recordOutcome(input, id); }
export async function reopenOpportunity(input: z.input<typeof ReopenOpportunityInputSchema>, id: string) { return (await defaults()).reopenOpportunity(input, id); }
