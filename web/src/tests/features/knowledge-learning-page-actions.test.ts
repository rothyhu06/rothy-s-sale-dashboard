import { describe, expect, it, vi } from "vitest";
import { VersionConflictError } from "@/lib/commands/version-conflict";

const updateKnowledge = vi.fn();
const completeLearning = vi.fn();
const createKnowledge = vi.fn();
const createLearning = vi.fn();
const createReviewLearning = vi.fn();

vi.mock("@/features/knowledge/actions", () => ({
  createKnowledge, updateKnowledge,
  VersionConflictError,
}));
vi.mock("@/features/learning/actions", () => ({
  completeLearning, createLearning, createReviewLearning,
}));

describe("optimistic conflict form actions", () => {
  it("returns a safe Knowledge conflict state rather than redirecting or leaking details", async () => {
    updateKnowledge.mockRejectedValueOnce(new VersionConflictError("Knowledge", 1));
    const { saveKnowledge } = await import("@/features/knowledge/page-actions");
    const data = new FormData();
    for (const [name, value] of Object.entries({ knowledgeId: crypto.randomUUID(), version: "1", title: "Knowledge", knowledgeType: "General", status: "Draft", confidence: "Hypothesis", sourceType: "Personal Note", dataLevel: "Level1", body: "Preserve this" })) data.set(name, value);
    await expect(saveKnowledge({}, data)).resolves.toMatchObject({ conflict: true, message: expect.stringContaining("edits are preserved") });
  });

  it("returns a safe Learning conflict state rather than redirecting or leaking details", async () => {
    completeLearning.mockRejectedValueOnce(new VersionConflictError("Learning", 1));
    const { finishLearning } = await import("@/features/learning/page-actions");
    const data = new FormData();
    for (const [name, value] of Object.entries({ learningId: crypto.randomUUID(), version: "1", learningOutcome: "Applied", practiceResult: "Preserve this" })) data.set(name, value);
    await expect(finishLearning({}, data)).resolves.toMatchObject({ conflict: true, message: expect.stringContaining("notes are preserved") });
  });
});

describe("stable command form identities", () => {
  it("passes the submitted clientRequestId to Knowledge create and update attempts", async () => {
    const clientRequestId = crypto.randomUUID();
    createKnowledge.mockRejectedValueOnce(new Error("expected stop"));
    const { submitKnowledge } = await import("@/features/knowledge/page-actions");
    const data = new FormData();
    for (const [name, value] of Object.entries({ clientRequestId, title: "Knowledge", knowledgeType: "General", status: "Draft", confidence: "Hypothesis", sourceType: "Personal Note", dataLevel: "Level1", body: "Body" })) data.set(name, value);
    await submitKnowledge({}, data);
    expect(createKnowledge).toHaveBeenCalledWith(expect.any(Object), clientRequestId);
  });

  it("passes the submitted clientRequestId and every mastery link to completion", async () => {
    const clientRequestId = crypto.randomUUID();
    completeLearning.mockRejectedValueOnce(new Error("expected stop"));
    const { finishLearning } = await import("@/features/learning/page-actions");
    const data = new FormData();
    for (const [name, value] of Object.entries({ clientRequestId, learningId: crypto.randomUUID(), version: "1", learningOutcome: "Applied" })) data.set(name, value);
    data.append("knowledgeId", crypto.randomUUID()); data.append("masteryAfter", "Apply");
    data.append("knowledgeId", crypto.randomUUID()); data.append("masteryAfter", "Teach");
    await finishLearning({}, data);
    expect(completeLearning).toHaveBeenCalledWith(expect.objectContaining({ knowledgeMastery: [expect.objectContaining({ masteryAfter: "Apply" }), expect.objectContaining({ masteryAfter: "Teach" })] }), 1, clientRequestId);
  });

  it("does not reflect a tampered completion/database failure", async () => {
    completeLearning.mockRejectedValueOnce(new Error("SQL select token=secret-form-value"));
    const { finishLearning } = await import("@/features/learning/page-actions");
    const data = new FormData();
    for (const [name, value] of Object.entries({ clientRequestId: crypto.randomUUID(), learningId: crypto.randomUUID(), version: "1", learningOutcome: "Applied" })) data.set(name, value);
    data.append("knowledgeId", crypto.randomUUID());
    data.append("masteryAfter", "Apply");
    const state = await finishLearning({}, data);
    expect(state.message).toBe("学习未能完成，请稍后重试。");
    expect(state.message).not.toMatch(/SQL|secret/i);
  });
});

describe("Review command integrity", () => {
  it("keeps ordinary Learning non-Review even when form fields are tampered", async () => {
    createLearning.mockRejectedValueOnce(new Error("expected stop"));
    const { submitLearning } = await import("@/features/learning/page-actions");
    const data = new FormData();
    data.set("clientRequestId", crypto.randomUUID());
    data.set("title", "Tampered");
    data.set("learningType", "Review");
    data.set("parentLearningId", crypto.randomUUID());
    await submitLearning({}, data);
    expect(createLearning).toHaveBeenCalledWith(expect.objectContaining({ learningType: "Study", parentLearningId: null }), expect.any(String));
    expect(createReviewLearning).not.toHaveBeenCalled();
  });

  it("binds the Review parent in the server action and ignores tampered parent/type fields", async () => {
    createReviewLearning.mockRejectedValueOnce(new Error("expected stop"));
    const parentId = crypto.randomUUID();
    const { submitReviewLearning } = await import("@/features/learning/page-actions");
    const data = new FormData();
    data.set("clientRequestId", crypto.randomUUID());
    data.set("title", "Review safely");
    data.set("learningType", "Study");
    data.set("parentLearningId", crypto.randomUUID());
    await submitReviewLearning(parentId, {}, data);
    expect(createReviewLearning).toHaveBeenCalledWith(expect.objectContaining({ learningType: "Review", parentLearningId: parentId }), expect.any(String));
  });
});
