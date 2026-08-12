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

function queryFailure(error: unknown) {
  const builder = queryResult(null);
  builder.single = vi.fn(async () => ({ data: null, error }));
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

  it("distinguishes an RLS-hidden/missing fact from an operational read failure", async () => {
    const id = crypto.randomUUID();
    const missing = createKnowledgeQueries({ client: { from: vi.fn(() => queryFailure({ code: "PGRST116" })) } as never });
    await expect(missing.getKnowledge(id)).rejects.toMatchObject({ name: "EntityNotFoundError" });
    const failed = createKnowledgeQueries({ client: { from: vi.fn(() => queryFailure({ code: "08006", message: "connection failed" })) } as never });
    await expect(failed.getKnowledge(id)).rejects.toMatchObject({ name: "Error", message: "Knowledge could not be loaded" });
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

  it("loads active tag/attachment options and every linked target for Learning", async () => {
    const id = crypto.randomUUID();
    const learning = queryResult([{ id, title: "Study", learning_type: "Study", status: "Planned", objective: null, started_at: null, completed_at: null, duration_minutes: null, takeaway: null, practice_result: null, learning_outcome: null, parent_learning_id: null, data_level: "Level2", classification_reason: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString(), version: 1 }]);
    const tagId = crypto.randomUUID();
    const attachmentId = crypto.randomUUID();
    const tags = queryResult([{ id: tagId, name: "AI", data_level: "Level1" }]);
    const attachments = queryResult([{ id: attachmentId, original_filename: "guide.pdf", file_category: "Document", storage_status: "Available", data_level: "Level1" }]);
    const tagLinks = queryResult([{ tag_id: tagId }]);
    const attachmentLinks = queryResult([{ attachment_id: attachmentId }]);
    const empty = queryResult([]);
    const from = vi.fn((table: string) => ({ learning, tags, attachments, tag_links: tagLinks, attachment_links: attachmentLinks, learning_knowledge_links: empty }[table] ?? empty));
    const queries = createLearningQueries({ client: { from, rpc: vi.fn() } as never });
    await expect(queries.getLearningSupport()).resolves.toMatchObject({ tags: [{ name: "AI" }], attachments: [{ original_filename: "guide.pdf" }] });
    await expect(queries.getLearning(id)).resolves.toMatchObject({ tags: [{ name: "AI" }], attachments: [{ original_filename: "guide.pdf" }] });
    expect(attachments.eq).toHaveBeenCalledWith("storage_status", "Available");
  });

  it("distinguishes missing Learning from an operational failure", async () => {
    const id = crypto.randomUUID();
    const missing = createLearningQueries({ client: { from: vi.fn(() => queryFailure({ code: "PGRST116" })), rpc: vi.fn() } as never });
    await expect(missing.getLearning(id)).rejects.toMatchObject({ name: "EntityNotFoundError" });
    const failed = createLearningQueries({ client: { from: vi.fn(() => queryFailure({ code: "XX000" })), rpc: vi.fn() } as never });
    await expect(failed.getLearning(id)).rejects.toMatchObject({ message: "Learning could not be loaded" });
  });
});
