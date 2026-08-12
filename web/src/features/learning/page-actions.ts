"use server";

import { redirect } from "next/navigation";
import { completeLearning, createLearning, createReviewLearning } from "./actions";
import { VersionConflictError } from "@/lib/commands/version-conflict";

export type LearningFormState = { message?: string; conflict?: boolean };
const text = (data: FormData, name: string) => String(data.get(name) ?? "").trim();
const nullable = (data: FormData, name: string) => text(data, name) || null;

export async function submitLearning(_state: LearningFormState, data: FormData): Promise<LearningFormState> {
  try {
    const learningType = text(data, "learningType");
    const knowledgeIds = data.getAll("knowledgeId").map(String).filter(Boolean);
    const masteryBefore = data.getAll("masteryBefore").map(String);
    const input = {
      title: text(data, "title"), learningType, status: text(data, "status") || "Planned", objective: nullable(data, "objective"),
      startedAt: nullable(data, "startedAt") ? new Date(text(data, "startedAt")).toISOString() : null,
      parentLearningId: nullable(data, "parentLearningId"), dataLevel: text(data, "dataLevel") || "Level2",
      attachmentIds: [], tagIds: [], knowledgeLinks: knowledgeIds.map((knowledgeId, index) => ({ knowledgeId, masteryBefore: masteryBefore[index] || "Aware", masteryAfter: masteryBefore[index] || "Aware" })),
    } as Parameters<typeof createLearning>[0];
    const result = learningType === "Review"
      ? await createReviewLearning(input, text(data, "clientRequestId"))
      : await createLearning(input, text(data, "clientRequestId"));
    redirect(`/learning/${result.id}`);
  } catch (error) {
    if ((error as { digest?: string }).digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { message: error instanceof Error ? error.message : "Learning could not be created" };
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
    return { message: error instanceof Error ? error.message : "Learning could not be completed" };
  }
}
