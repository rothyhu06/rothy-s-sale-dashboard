"use server";

import { redirect } from "next/navigation";
import { completeLearning, createLearning, createReviewLearning } from "./actions";
import { VersionConflictError } from "@/lib/commands/version-conflict";
import { safeActionError } from "@/lib/actions/safe-action-error";

export type LearningFormState = { message?: string; conflict?: boolean };
const text = (data: FormData, name: string) => String(data.get(name) ?? "").trim();
const nullable = (data: FormData, name: string) => text(data, name) || null;
const selected = (data: FormData, name: string) => data.getAll(name).map(String).filter(Boolean);
const ordinaryLearningTypes = new Set(["Study", "Practice", "Course", "Product Training", "Case Analysis"]);

function learningInput(data: FormData, options?: { parentLearningId: string }) {
  const requestedType = text(data, "learningType");
  const learningType = options ? "Review" : ordinaryLearningTypes.has(requestedType) ? requestedType : "Study";
  const knowledgeIds = selected(data, "knowledgeId");
  return {
    title: text(data, "title"), learningType, status: text(data, "status") || "Planned", objective: nullable(data, "objective"),
    startedAt: nullable(data, "startedAt") ? new Date(text(data, "startedAt")).toISOString() : null,
    parentLearningId: options?.parentLearningId ?? null, dataLevel: text(data, "dataLevel") || "Level2",
    attachmentIds: selected(data, "attachmentIds"), tagIds: selected(data, "tagIds"),
    knowledgeLinks: knowledgeIds.map((knowledgeId) => { const mastery = text(data, `masteryBefore-${knowledgeId}`) || "Aware"; return { knowledgeId, masteryBefore: mastery, masteryAfter: mastery }; }),
  } as Parameters<typeof createLearning>[0];
}

export async function submitLearning(_state: LearningFormState, data: FormData): Promise<LearningFormState> {
  try {
    const result = await createLearning(learningInput(data), text(data, "clientRequestId"));
    redirect(`/learning/${result.id}`);
  } catch (error) {
    if ((error as { digest?: string }).digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { message: safeActionError(error, { operation: "create-learning", fallback: "学习记录未能创建，请稍后重试。" }) };
  }
}

export async function submitReviewLearning(parentLearningId: string, _state: LearningFormState, data: FormData): Promise<LearningFormState> {
  try {
    const result = await createReviewLearning(learningInput(data, { parentLearningId }), text(data, "clientRequestId"));
    redirect(`/learning/${result.id}`);
  } catch (error) {
    if ((error as { digest?: string }).digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { message: safeActionError(error, { operation: "create-review-learning", fallback: "复习记录未能创建，请稍后重试。" }) };
  }
}

export async function finishLearning(_state: LearningFormState, data: FormData): Promise<LearningFormState> {
  try {
    const learningId = text(data, "learningId");
    const knowledgeIds = data.getAll("knowledgeId").map(String).filter(Boolean);
    const masteryAfter = data.getAll("masteryAfter").map(String);
    await completeLearning({
      learningId, completedAt: new Date().toISOString(), durationMinutes: Number(text(data, "durationMinutes")) || null,
      takeaway: nullable(data, "takeaway"), practiceResult: nullable(data, "practiceResult"), learningOutcome: text(data, "learningOutcome"),
      knowledgeMastery: knowledgeIds.map((knowledgeId, index) => ({ knowledgeId, masteryAfter: masteryAfter[index] })),
    } as Parameters<typeof completeLearning>[0], Number(text(data, "version")), text(data, "clientRequestId"));
    redirect(`/learning/${learningId}`);
  } catch (error) {
    if ((error as { digest?: string }).digest?.startsWith("NEXT_REDIRECT")) throw error;
    if (error instanceof VersionConflictError) return { conflict: true, message: "This Learning changed in another session. Your completion notes are preserved; reload before trying again." };
    return { message: safeActionError(error, { operation: "complete-learning", fallback: "学习未能完成，请稍后重试。" }) };
  }
}
