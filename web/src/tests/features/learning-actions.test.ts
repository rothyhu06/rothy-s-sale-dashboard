import { beforeEach, describe, expect, it, vi } from "vitest";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const learningId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const parentLearningId = "13e10280-2c70-42dc-902d-ec1de049f083";
const knowledgeId = "8dfd9adc-4c1d-4bf6-af3b-4b7445b1c019";
const clientRequestId = "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f";
const operationId = "60d74e72-8209-42df-ab94-eace52caf1b3";

const { createCommandContext } = vi.hoisted(() => ({ createCommandContext: vi.fn() }));
vi.mock("@/lib/commands/command-context", () => ({ createCommandContext }));

import {
  CreateLearningCommandInputSchema,
  createLearningActions,
} from "@/features/learning/actions";
import { createLearningQueries } from "@/features/learning/queries";

function serviceClient() {
  return {
    rpc: vi.fn().mockResolvedValue({ data: [{
      id: learningId,
      title: "复习 AI 助教",
      status: "Planned",
      version: 1,
      operation_id: operationId,
    }], error: null }),
  };
}

describe("Learning domain commands", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    createCommandContext.mockImplementation((commandType: string, requestId: string) => Promise.resolve({
      user: { sub: ownerId }, commandType, clientRequestId: requestId,
    }));
  });

  it("accepts only the fixed mastery scale and rejects mastery regression", () => {
    const input = {
      title: "学习 AI 助教",
      learningType: "Study" as const,
      status: "Planned" as const,
      knowledgeLinks: [{ knowledgeId, masteryBefore: "Aware" as const, masteryAfter: "Understand" as const }],
    };
    expect(CreateLearningCommandInputSchema.parse(input).knowledgeLinks).toHaveLength(1);
    expect(() => CreateLearningCommandInputSchema.parse({
      ...input,
      knowledgeLinks: [{ knowledgeId, masteryBefore: "Expert", masteryAfter: "Teach" }],
    })).toThrow();
    expect(() => CreateLearningCommandInputSchema.parse({
      ...input,
      knowledgeLinks: [{ knowledgeId, masteryBefore: "Apply", masteryAfter: "Understand" }],
    })).toThrow("Mastery cannot decrease");
  });

  it("creates a Review as a new owner-scoped fact with its parent and client request id", async () => {
    const client = serviceClient();
    const actions = createLearningActions({ authClient: {} as never, serviceClient: client });

    await actions.createReviewLearning({
      title: "复习 AI 助教",
      learningType: "Review",
      status: "Planned",
      parentLearningId,
      knowledgeLinks: [{ knowledgeId, masteryBefore: "Understand", masteryAfter: "Explain" }],
    }, clientRequestId);

    expect(client.rpc).toHaveBeenCalledWith("create_review_learning", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_parent_learning_id: parentLearningId,
      p_knowledge_links: [{ knowledgeId, masteryBefore: "Understand", masteryAfter: "Explain" }],
    }));
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("owner_id");
  });

  it("requires a client request id for completion and sends the optimistic version", async () => {
    const client = serviceClient();
    const actions = createLearningActions({ authClient: {} as never, serviceClient: client });

    await actions.completeLearning({
      learningId,
      completedAt: "2026-08-04T10:00:00.000Z",
      durationMinutes: 45,
      takeaway: "能够向客户解释",
      learningOutcome: "Passed",
      knowledgeMastery: [{ knowledgeId, masteryAfter: "Explain" }],
    }, 3, clientRequestId);

    expect(client.rpc).toHaveBeenCalledWith("complete_learning_exact", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_expected_version: 3,
      p_learning_id: learningId,
    }));
  });

  it("soft-deletes Learning through an optimistic replay-safe domain command", async () => {
    const client = serviceClient();
    const actions = createLearningActions({ authClient: {} as never, serviceClient: client });

    await actions.deleteLearning({ learningId }, 5, clientRequestId);

    expect(client.rpc).toHaveBeenCalledWith("delete_learning", {
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_learning_id: learningId,
      p_expected_version: 5,
    });
  });
});

describe("Continue Learning", () => {
  it("uses the RLS fact query with deterministic priority and returns chain fields", async () => {
    const client = { rpc: vi.fn().mockResolvedValue({ data: [{
      id: learningId,
      title: "继续学习",
      learning_type: "Review",
      status: "In Progress",
      objective: "巩固",
      started_at: "2026-08-04T09:00:00.000Z",
      completed_at: null,
      learning_outcome: null,
      parent_learning_id: parentLearningId,
      updated_at: "2026-08-04T10:00:00.000Z",
      version: 2,
    }], error: null }) };
    const queries = createLearningQueries({ client: client as never });

    const result = await queries.getContinueLearning(4);

    expect(client.rpc).toHaveBeenCalledWith("get_continue_learning", { p_limit: 4 });
    expect(result[0]).toMatchObject({
      id: learningId,
      parentLearningId,
      status: "In Progress",
      learningOutcome: null,
    });
  });
});
