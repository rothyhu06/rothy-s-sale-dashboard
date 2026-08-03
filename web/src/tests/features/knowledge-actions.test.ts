import { beforeEach, describe, expect, it, vi } from "vitest";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const knowledgeId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const clientRequestId = "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f";
const operationId = "60d74e72-8209-42df-ab94-eace52caf1b3";
const attachmentId = "8dfd9adc-4c1d-4bf6-af3b-4b7445b1c019";

const { createCommandContext } = vi.hoisted(() => ({ createCommandContext: vi.fn() }));
vi.mock("@/lib/commands/command-context", () => ({ createCommandContext }));

import {
  VersionConflictError,
  createKnowledgeActions,
} from "@/features/knowledge/actions";
import { createKnowledgeQueries } from "@/features/knowledge/queries";

const baseInput = {
  title: "腾讯云 AI 助教",
  knowledgeType: "Tencent Cloud Product" as const,
  status: "Ready" as const,
  confidence: "Official" as const,
  sourceType: "Official Doc" as const,
  summary: "面向教师的备课助手",
  dataLevel: "Level1" as const,
  contentBlocks: {
    schemaVersion: 1 as const,
    blocks: [{
      id: "p1",
      type: "attachmentReference" as const,
      attachmentId,
      caption: "产品白皮书",
    }],
  },
  tagIds: ["c5782c4a-335b-4acd-9a7e-bf462cf9a8f4"],
  relations: [{
    relatedKnowledgeId: "13e10280-2c70-42dc-902d-ec1de049f083",
    relationType: "Depends On",
  }],
};

function serviceClient(error: unknown = null) {
  return {
    rpc: vi.fn().mockResolvedValue({
      data: error ? null : [{
        id: knowledgeId,
        title: baseInput.title,
        content_plaintext: "产品白皮书",
        data_level: "Level3",
        version: 1,
        operation_id: operationId,
      }],
      error,
    }),
  };
}

describe("Knowledge domain commands", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    createCommandContext.mockImplementation((commandType: string, requestId: string) => Promise.resolve({
      user: { sub: ownerId }, commandType, clientRequestId: requestId,
    }));
  });

  it("injects the verified owner and leaves attachment state, level, and plaintext authority to PostgreSQL", async () => {
    const client = serviceClient();
    const attachmentRepository = {
      findByIds: vi.fn().mockResolvedValue([{
        id: attachmentId,
        owner_id: ownerId,
        storage_status: "Available",
        deleted_at: null,
        file_category: "Document",
        data_level: "Level3",
      }]),
    };
    const actions = createKnowledgeActions({
      authClient: {} as never,
      serviceClient: client,
      attachmentRepository,
    });

    const result = await actions.createKnowledge(baseInput, clientRequestId);

    expect(attachmentRepository.findByIds).not.toHaveBeenCalled();
    expect(client.rpc).toHaveBeenCalledWith("create_knowledge", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_content_blocks: baseInput.contentBlocks,
      p_data_level: "Level1",
      p_attachment_ids: [attachmentId],
      p_tag_ids: baseInput.tagIds,
      p_relations: baseInput.relations,
    }));
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("p_content_plaintext");
    expect(client.rpc.mock.calls[0]?.[1]).not.toHaveProperty("owner_id");
    expect(result).toMatchObject({ id: knowledgeId, contentPlaintext: "产品白皮书", operationId });
  });

  it("always reaches the replay-first RPC even when an attachment would now fail optional UX validation", async () => {
    const client = serviceClient();
    const attachmentRepository = { findByIds: vi.fn().mockRejectedValue(new Error("now unavailable")) };
    const actions = createKnowledgeActions({ authClient: {} as never, serviceClient: client, attachmentRepository });

    await expect(actions.createKnowledge(baseInput, clientRequestId)).resolves.toMatchObject({
      id: knowledgeId,
      operationId,
    });
    expect(attachmentRepository.findByIds).not.toHaveBeenCalled();
    expect(client.rpc).toHaveBeenCalledOnce();
  });

  it("sends a presence-preserving patch for title-only updates", async () => {
    const client = serviceClient();
    const actions = createKnowledgeActions({
      authClient: {} as never,
      serviceClient: client,
      attachmentRepository: { findByIds: vi.fn() },
    });

    await actions.updateKnowledge({ knowledgeId, title: "仅修改标题" }, 2, clientRequestId);

    expect(client.rpc).toHaveBeenCalledWith("update_knowledge", {
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_knowledge_id: knowledgeId,
      p_expected_version: 2,
      p_patch: { title: "仅修改标题" },
    });
  });

  it("preserves explicit empty arrays and nulls in an intentional clear patch", async () => {
    const client = serviceClient();
    const actions = createKnowledgeActions({
      authClient: {} as never,
      serviceClient: client,
      attachmentRepository: { findByIds: vi.fn() },
    });
    const contentBlocks = { schemaVersion: 1 as const, blocks: [] };

    await actions.updateKnowledge({
      knowledgeId,
      sourceName: null,
      contentBlocks,
      attachmentIds: [],
      tagIds: [],
      relations: [],
    }, 3, clientRequestId);

    expect(client.rpc).toHaveBeenCalledWith("update_knowledge", expect.objectContaining({
      p_patch: { sourceName: null, contentBlocks, attachmentIds: [], tagIds: [], relations: [] },
    }));
  });

  it("maps PostgreSQL optimistic-lock conflicts to a safe typed 409 error", async () => {
    const client = serviceClient({ code: "40001", message: "knowledge version conflict", details: null });
    const actions = createKnowledgeActions({
      authClient: {} as never,
      serviceClient: client,
      attachmentRepository: { findByIds: vi.fn().mockResolvedValue([]) },
    });

    await expect(actions.updateKnowledge({ knowledgeId, title: "冲突" }, 7, clientRequestId)).rejects.toMatchObject({
      name: "VersionConflictError",
      status: 409,
      entityType: "Knowledge",
      expectedVersion: 7,
    } satisfies Partial<VersionConflictError>);
    expect(client.rpc).toHaveBeenCalledWith("update_knowledge", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_expected_version: 7,
      p_patch: { title: "冲突" },
    }));
  });

  it("soft-deletes Knowledge through an optimistic replay-safe domain command", async () => {
    const client = serviceClient();
    const actions = createKnowledgeActions({
      authClient: {} as never,
      serviceClient: client,
      attachmentRepository: { findByIds: vi.fn() },
    });

    await actions.deleteKnowledge({ knowledgeId }, 4, clientRequestId);

    expect(client.rpc).toHaveBeenCalledWith("delete_knowledge", {
      p_verified_user_id: ownerId,
      p_client_request_id: clientRequestId,
      p_knowledge_id: knowledgeId,
      p_expected_version: 4,
    });
  });
});

describe("Knowledge local search", () => {
  it("queries only the owner-filtered SearchDocument projection with an escaped pattern", async () => {
    const query = {
      eq: vi.fn(), ilike: vi.fn(), order: vi.fn(), limit: vi.fn(),
    };
    query.eq.mockReturnValue(query);
    query.ilike.mockReturnValue(query);
    query.order.mockReturnValue(query);
    query.limit.mockResolvedValue({ data: [], error: null });
    const client = { from: vi.fn().mockReturnValue({ select: vi.fn().mockReturnValue(query) }) };
    const queries = createKnowledgeQueries({ client: client as never });

    await queries.searchKnowledge("  100%_AI  ", 12);

    expect(client.from).toHaveBeenCalledWith("search_documents");
    expect(query.eq).toHaveBeenCalledWith("source_type", "Knowledge");
    expect(query.ilike).toHaveBeenCalledWith("search_text", "%100\\%\\_AI%");
    expect(query.limit).toHaveBeenCalledWith(12);
  });
});
