import { beforeEach, describe, expect, it, vi } from "vitest";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const customerId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const opportunityId = "8dfd9adc-4c1d-4bf6-af3b-4b7445b1c019";
const historyId = "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f";
const requestId = "f98ef0d8-64b1-4af6-948d-12cccbfe141e";

const { createCommandContext } = vi.hoisted(() => ({ createCommandContext: vi.fn() }));
vi.mock("@/lib/commands/command-context", () => ({ createCommandContext }));

import {
  CreateOpportunityInputSchema,
  OpportunityOutcomeInputSchema,
  OpportunityStageSchema,
  TransitionOpportunityInputSchema,
} from "@/features/opportunities/schema";
import { createOpportunityActions } from "@/features/opportunities/actions";
import { deriveOpportunityProjection } from "@/features/opportunities/projection";
import { createOpportunityQueries } from "@/features/opportunities/queries";

function rpcClient(result: unknown) {
  return { rpc: vi.fn().mockResolvedValue({ data: result, error: null }) };
}

describe("Opportunity authority contracts", () => {
  it("uses the exact frozen stages and does not encode probability or Renewal as a stage", () => {
    expect(OpportunityStageSchema.options).toEqual([
      "Lead", "Discovery", "Needs Confirmed", "Solution Design", "POC",
      "Commercial Negotiation", "Closed Won", "Closed Lost",
    ]);
    expect(OpportunityStageSchema.safeParse("Renewal").success).toBe(false);
    expect(CreateOpportunityInputSchema.parse({
      customerId, name: "Campus AI platform", opportunityType: "Renewal",
      parentOpportunityId: opportunityId, estimatedAmount: 200_000, currency: "CNY",
      amountBasis: "Customer budget", amountAsOf: "2026-08-01",
    })).not.toHaveProperty("probability");
  });

  it("keeps estimated amount on Opportunity and final amount on Outcome", () => {
    const opportunity = CreateOpportunityInputSchema.parse({
      customerId, name: "Campus AI platform", opportunityType: "New Business",
      estimatedAmount: 200_000, currency: "CNY", amountBasis: "Customer budget",
      amountAsOf: "2026-08-01",
    });
    const outcome = OpportunityOutcomeInputSchema.parse({
      opportunityId, expectedVersion: 3, expectedCurrentStageHistoryId: historyId,
      outcomeType: "Won", finalAmount: 188_000, currency: "CNY",
      decisionDate: "2026-08-13", reason: "Value and fit",
    });
    expect(opportunity.estimatedAmount).toBe(200_000);
    expect(opportunity).not.toHaveProperty("finalAmount");
    expect(outcome.finalAmount).toBe(188_000);
    expect(outcome).not.toHaveProperty("estimatedAmount");
  });

  it("accepts real ISO 4217 currencies and rejects formatting-only impostors", () => {
    const base = { customerId, name: "Campus AI platform", opportunityType: "New Business" } as const;
    const provenance = { amountBasis: "Customer budget", amountAsOf: "2026-08-01" };
    expect(CreateOpportunityInputSchema.safeParse({ ...base, ...provenance, currency: "CNY", estimatedAmount: 1 }).success).toBe(true);
    expect(CreateOpportunityInputSchema.safeParse({ ...base, ...provenance, currency: "cny", estimatedAmount: 1 }).success).toBe(false);
    expect(CreateOpportunityInputSchema.safeParse({ ...base, ...provenance, currency: "ZZZ", estimatedAmount: 1 }).success).toBe(false);
    expect(CreateOpportunityInputSchema.safeParse({ ...base, currency: "CNY" }).success).toBe(false);
  });

  it("requires version and current history identity for transition concurrency", () => {
    expect(TransitionOpportunityInputSchema.safeParse({ opportunityId, toStage: "Discovery" }).success).toBe(false);
    const parsed = TransitionOpportunityInputSchema.parse({
      opportunityId, toStage: "Discovery", expectedVersion: 1,
      expectedCurrentStageHistoryId: historyId, changedSource: "Manual",
    });
    expect(parsed).not.toHaveProperty("transitionType");
  });
});

describe("Opportunity commands", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    createCommandContext.mockResolvedValue({ user: { sub: ownerId }, clientRequestId: requestId });
  });

  it("creates Opportunity, Initial history, roles, search, audit and receipt through one owner-injected RPC", async () => {
    const client = rpcClient([{ id: opportunityId, name: "Campus AI platform", version: 1, current_stage_history_id: historyId, operation_id: crypto.randomUUID() }]);
    const actions = createOpportunityActions({ authClient: {} as never, serviceClient: client as never });
    await actions.createOpportunity({
      customerId, name: "Campus AI platform", opportunityType: "New Business",
      sourceType: "Inbound", estimatedAmount: 200_000, currency: "CNY",
      amountBasis: "Customer budget", amountAsOf: "2026-08-01",
      contactRoles: [{ contactId: crypto.randomUUID(), role: "Decision Maker", supportLevel: "Supportive" }],
    }, requestId);
    expect(client.rpc).toHaveBeenCalledWith("create_opportunity", expect.objectContaining({
      p_verified_user_id: ownerId, p_initial_stage: "Lead",
      p_contact_roles: [expect.objectContaining({ role: "Decision Maker" })],
    }));
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("owner_id");
  });

  it("never trusts a client transition type", async () => {
    const client = rpcClient([{ opportunity_id: opportunityId, version: 2, stage_history_id: crypto.randomUUID(), current_stage: "Discovery", transition_type: "Forward", operation_id: crypto.randomUUID() }]);
    const actions = createOpportunityActions({ authClient: {} as never, serviceClient: client as never });
    await actions.transitionOpportunity({ opportunityId, toStage: "Discovery", expectedVersion: 1, expectedCurrentStageHistoryId: historyId, changedSource: "Manual" }, requestId);
    expect(client.rpc).toHaveBeenCalledWith("transition_opportunity", expect.objectContaining({
      p_verified_user_id: ownerId, p_expected_version: 1,
      p_expected_current_stage_history_id: historyId, p_to_stage: "Discovery",
    }));
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("p_transition_type");
  });

  it("records immutable outcome separately and reopens through an explicit voiding command", async () => {
    const client = rpcClient([{ opportunity_id: opportunityId, outcome_id: crypto.randomUUID(), version: 4, operation_id: crypto.randomUUID() }]);
    const actions = createOpportunityActions({ authClient: {} as never, serviceClient: client as never });
    await actions.recordOutcome({
      opportunityId, expectedVersion: 3, expectedCurrentStageHistoryId: historyId,
      outcomeType: "Won", finalAmount: 188_000, currency: "CNY", decisionDate: "2026-08-13", reason: "Value and fit",
    }, requestId);
    expect(client.rpc).toHaveBeenLastCalledWith("record_opportunity_outcome", expect.objectContaining({ p_final_amount: 188_000 }));
    await actions.reopenOpportunity({
      opportunityId, toStage: "Commercial Negotiation", expectedVersion: 4,
      expectedCurrentStageHistoryId: historyId, reason: "Procurement reopened evaluation",
    }, crypto.randomUUID());
    expect(client.rpc).toHaveBeenLastCalledWith("reopen_opportunity", expect.objectContaining({ p_to_stage: "Commercial Negotiation" }));
  });
});

describe("Opportunity projection", () => {
  it("derives stage timing, closed state, progress and deterministic stalled state at as_of", () => {
    const projection = deriveOpportunityProjection({
      opportunityId, currentStage: "Discovery", stageEnteredAt: "2026-07-01T00:00:00.000Z",
      lastProgressAt: "2026-07-03T00:00:00.000Z", nextTaskDueAt: null,
      activeOutcome: null, asOf: "2026-07-20T00:00:00.000Z", stalledAfterDays: 14,
    });
    expect(projection).toMatchObject({
      currentStage: "Discovery", daysInStage: 19, isClosed: false, isStalled: true,
      lastProgressAt: "2026-07-03T00:00:00.000Z", nextTaskDueAt: null,
      forecastCategory: null, outcomeReviewMissing: false,
    });
  });

  it("reports a missing review only for an active closed outcome without review completion", () => {
    expect(deriveOpportunityProjection({
      opportunityId, currentStage: "Closed Lost", stageEnteredAt: "2026-08-10T00:00:00.000Z",
      lastProgressAt: "2026-08-10T00:00:00.000Z", nextTaskDueAt: null,
      activeOutcome: { outcomeType: "Lost", reviewCompletedAt: null },
      asOf: "2026-08-13T00:00:00.000Z", stalledAfterDays: 14,
    }).outcomeReviewMissing).toBe(true);
  });

  it("queries the owner-scoped deterministic projection RPC with explicit as_of and threshold", async () => {
    const client = rpcClient([{ opportunity_id: opportunityId, current_stage: "Lead", stage_entered_at: "2026-08-13T00:00:00Z", days_in_stage: 0, is_closed: false, is_stalled: false, last_progress_at: "2026-08-13T00:00:00Z", next_task_due_at: null, forecast_category: null, outcome_review_missing: false, projection_schema_version: 1 }]);
    await createOpportunityQueries({ client: client as never }).getOpportunityProjection(opportunityId, { asOf: "2026-08-13T00:00:00Z", stalledAfterDays: 14 });
    expect(client.rpc).toHaveBeenCalledWith("get_opportunity_projection", {
      p_opportunity_id: opportunityId, p_as_of: "2026-08-13T00:00:00.000Z", p_stalled_after_days: 14,
    });
  });
});
