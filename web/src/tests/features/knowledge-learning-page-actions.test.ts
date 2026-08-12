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
});
