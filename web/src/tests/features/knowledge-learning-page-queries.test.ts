import { describe, expect, it, vi } from "vitest";
import { createKnowledgeQueries } from "@/features/knowledge/queries";
import { createLearningQueries } from "@/features/learning/queries";

function queryResult(data: unknown) {
  const builder: Record<string, ReturnType<typeof vi.fn>> = {};
  for (const method of ["select", "eq", "is", "in", "order", "limit"]) {
    builder[method] = vi.fn(() => builder);
  }
  builder.single = vi.fn(async () => ({ data: Array.isArray(data) ? data[0] : data, error: null }));
  builder.then = vi.fn((resolve: (value: unknown) => unknown) => resolve({ data, error: null }));
  return builder;
}

describe("Knowledge page queries", () => {
  it("loads owner-RLS Knowledge and support collections without a service client", async () => {
    const knowledge = queryResult([{ id: crypto.randomUUID(), title: "AI", knowledge_type: "AI Technology", status: "Learning", confidence: "Verified", source_type: "Official Doc", source_name: null, source_url: null, summary: "Summary", technical_principle: null, business_value: null, education_scenario: null, customer_pain_point: null, sales_expression: null, customer_questions: null, competitive_note: null, content_blocks: { schemaVersion: 1, blocks: [] }, content_plaintext: "", data_level: "Level1", classification_reason: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString(), version: 1 }]);
    const tags = queryResult([]);
    const attachments = queryResult([]);
    const from = vi.fn((table: string) => ({ knowledge, tags, attachments }[table]));

    const queries = createKnowledgeQueries({ client: { from } as never });
    await expect(queries.listKnowledge()).resolves.toHaveLength(1);
    await expect(queries.getKnowledgeSupport()).resolves.toMatchObject({ tags: [], attachments: [], knowledge: [{ title: "AI" }] });
    expect(from).toHaveBeenCalledWith("knowledge");
    expect(from).toHaveBeenCalledWith("tags");
    expect(from).toHaveBeenCalledWith("attachments");
    expect(knowledge.limit).not.toHaveBeenCalled();
  });
});

describe("Learning page queries", () => {
  it("loads Learning facts and a linked detail chain through owner-RLS tables", async () => {
    const id = crypto.randomUUID();
    const parentId = crypto.randomUUID();
    const learning = queryResult([{ id, title: "Review", learning_type: "Review", status: "Planned", objective: null, started_at: null, completed_at: null, duration_minutes: null, takeaway: null, practice_result: null, learning_outcome: null, parent_learning_id: parentId, data_level: "Level2", classification_reason: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString(), version: 1 }]);
    const links = queryResult([]);
    const from = vi.fn((table: string) => table === "learning" ? learning : links);

    const queries = createLearningQueries({ client: { from, rpc: vi.fn() } as never });
    await expect(queries.listLearning()).resolves.toHaveLength(1);
    await expect(queries.getLearning(id)).resolves.toMatchObject({ id, parentLearningId: parentId, knowledgeLinks: [] });
    expect(from).toHaveBeenCalledWith("learning_knowledge_links");
  });
});
