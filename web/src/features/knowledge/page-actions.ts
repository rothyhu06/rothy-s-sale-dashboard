"use server";

import { redirect } from "next/navigation";
import { createKnowledge, updateKnowledge, VersionConflictError } from "./actions";
import { composeKnowledgeDocument } from "./form-adapter";

export type KnowledgeFormState = { message?: string; conflict?: boolean };
const text = (data: FormData, name: string) => String(data.get(name) ?? "").trim();
const nullable = (data: FormData, name: string) => text(data, name) || null;
const selected = (data: FormData, name: string) => data.getAll(name).map(String);

function value(data: FormData) {
  const attachmentIds = selected(data, "attachmentIds");
  const body = text(data, "body");
  const originalBody = text(data, "originalBody");
  const originalDocument = text(data, "originalContentBlocks");
  const document = composeKnowledgeDocument({
    body, originalBody, originalDocument: originalDocument ? JSON.parse(originalDocument) : undefined, attachmentIds,
  });
  return {
    title: text(data, "title"), knowledgeType: text(data, "knowledgeType"), status: text(data, "status"),
    confidence: text(data, "confidence"), sourceType: text(data, "sourceType"), sourceName: nullable(data, "sourceName"),
    sourceUrl: nullable(data, "sourceUrl"), summary: nullable(data, "summary"), technicalPrinciple: nullable(data, "technicalPrinciple"),
    businessValue: nullable(data, "businessValue"), educationScenario: nullable(data, "educationScenario"), customerPainPoint: nullable(data, "customerPainPoint"),
    salesExpression: nullable(data, "salesExpression"), customerQuestions: nullable(data, "customerQuestions"), competitiveNote: nullable(data, "competitiveNote"),
    dataLevel: text(data, "dataLevel"), classificationReason: nullable(data, "classificationReason"), contentBlocks: document,
    tagIds: selected(data, "tagIds"), relations: selected(data, "relatedKnowledgeIds").map((relatedKnowledgeId) => ({ relatedKnowledgeId, relationType: "Related" })),
  } as Parameters<typeof createKnowledge>[0];
}

export async function submitKnowledge(_state: KnowledgeFormState, data: FormData): Promise<KnowledgeFormState> {
  try {
    const result = await createKnowledge(value(data), text(data, "clientRequestId"));
    redirect(`/knowledge/${result.id}`);
  } catch (error) {
    if ((error as { digest?: string }).digest?.startsWith("NEXT_REDIRECT")) throw error;
    return { message: error instanceof Error ? error.message : "Knowledge could not be created" };
  }
}

export async function saveKnowledge(_state: KnowledgeFormState, data: FormData): Promise<KnowledgeFormState> {
  try {
    const knowledgeId = text(data, "knowledgeId");
    await updateKnowledge({ knowledgeId, ...value(data) }, Number(text(data, "version")), text(data, "clientRequestId"));
    redirect(`/knowledge/${knowledgeId}`);
  } catch (error) {
    if ((error as { digest?: string }).digest?.startsWith("NEXT_REDIRECT")) throw error;
    if (error instanceof VersionConflictError) return { conflict: true, message: "This Knowledge changed in another session. Your edits are preserved; reload the latest version before saving again." };
    return { message: error instanceof Error ? error.message : "Knowledge could not be saved" };
  }
}
