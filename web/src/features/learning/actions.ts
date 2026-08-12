import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import { throwDomainCommandError } from "@/lib/commands/version-conflict";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
import { CreateLearningInputSchema, LearningOutcomeSchema, MasterySchema } from "./schema";

const masteryRank = { Aware: 1, Understand: 2, Explain: 3, Apply: 4, Teach: 5 } as const;
const knowledgeLinkSchema = z.object({
  knowledgeId: z.uuid(),
  masteryBefore: MasterySchema,
  masteryAfter: MasterySchema,
}).strict().superRefine((value, context) => {
  if (masteryRank[value.masteryAfter] < masteryRank[value.masteryBefore]) {
    context.addIssue({ code: "custom", path: ["masteryAfter"], message: "Mastery cannot decrease" });
  }
});

export const CreateLearningCommandInputSchema = CreateLearningInputSchema.safeExtend({
  attachmentIds: z.array(z.uuid()).max(100).default([]),
  tagIds: z.array(z.uuid()).max(100).default([]),
  knowledgeLinks: z.array(knowledgeLinkSchema).max(100).default([]),
});

export const CompleteLearningInputSchema = z.object({
  learningId: z.uuid(),
  completedAt: z.iso.datetime({ offset: true }),
  durationMinutes: z.number().int().min(0).max(1_440).nullable().optional(),
  takeaway: z.string().trim().max(20_000).nullable().optional(),
  practiceResult: z.string().trim().max(20_000).nullable().optional(),
  learningOutcome: LearningOutcomeSchema,
  knowledgeMastery: z.array(z.object({
    knowledgeId: z.uuid(),
    masteryAfter: MasterySchema,
  }).strict()).max(100).default([]),
}).strict();
const deleteLearningInputSchema = z.object({ learningId: z.uuid() }).strict();

const learningRowSchema = z.object({
  id: z.uuid(),
  title: z.string(),
  status: z.enum(["Planned", "In Progress", "Completed", "Cancelled"]),
  version: z.coerce.number().int().positive(),
  operation_id: z.uuid(),
});

type RpcClient = Pick<SupabaseClient, "rpc">;
type LearningDependencies = {
  authClient: Parameters<typeof createCommandContext>[2];
  serviceClient: RpcClient;
};

function rowFrom(data: unknown) {
  const row = learningRowSchema.parse(Array.isArray(data) ? data[0] : data);
  return {
    id: row.id,
    title: row.title,
    status: row.status,
    version: row.version,
    operationId: row.operation_id,
  };
}

function createParams(
  value: z.infer<typeof CreateLearningCommandInputSchema>,
  ownerId: string,
  clientRequestId: string,
) {
  return {
    p_verified_user_id: ownerId,
    p_client_request_id: clientRequestId,
    p_title: value.title,
    p_learning_type: value.learningType,
    p_status: value.status,
    p_objective: value.objective ?? null,
    p_started_at: value.startedAt ?? null,
    p_completed_at: value.completedAt ?? null,
    p_duration_minutes: value.durationMinutes ?? null,
    p_takeaway: value.takeaway ?? null,
    p_practice_result: value.practiceResult ?? null,
    p_learning_outcome: value.learningOutcome ?? null,
    p_parent_learning_id: value.parentLearningId ?? null,
    p_data_level: value.dataLevel,
    p_classification_reason: value.classificationReason ?? null,
    p_attachment_ids: value.attachmentIds,
    p_tag_ids: value.tagIds,
    p_knowledge_links: value.knowledgeLinks,
  };
}

export function createLearningActions(dependencies: LearningDependencies) {
  async function create(input: z.input<typeof CreateLearningCommandInputSchema>, clientRequestId: string, review: boolean) {
    const value = CreateLearningCommandInputSchema.parse(input);
    if (review && value.learningType !== "Review") throw new Error("Review command requires Review learningType");
    if (!review && value.learningType === "Review") throw new Error("Review Learning must use createReviewLearning");
    const commandType = review ? "CreateReviewLearning" : "CreateLearning";
    const context = await createCommandContext(commandType, clientRequestId, dependencies.authClient);
    const params = createParams(value, context.user.sub, context.clientRequestId);
    const rpcName = review ? "create_review_learning" : "create_learning";
    const reviewParams = {
      p_verified_user_id: params.p_verified_user_id,
      p_client_request_id: params.p_client_request_id,
      p_title: params.p_title,
      p_status: params.p_status,
      p_objective: params.p_objective,
      p_started_at: params.p_started_at,
      p_completed_at: params.p_completed_at,
      p_duration_minutes: params.p_duration_minutes,
      p_takeaway: params.p_takeaway,
      p_practice_result: params.p_practice_result,
      p_learning_outcome: params.p_learning_outcome,
      p_parent_learning_id: params.p_parent_learning_id,
      p_data_level: params.p_data_level,
      p_classification_reason: params.p_classification_reason,
      p_attachment_ids: params.p_attachment_ids,
      p_tag_ids: params.p_tag_ids,
      p_knowledge_links: params.p_knowledge_links,
    };
    const { data, error } = await dependencies.serviceClient.rpc(rpcName, review ? reviewParams : params);
    if (error) throwDomainCommandError(error, { entityType: "Learning", fallback: "Learning could not be created" });
    return rowFrom(data);
  }

  return {
    createLearning(input: z.input<typeof CreateLearningCommandInputSchema>, clientRequestId: string) {
      return create(input, clientRequestId, false);
    },

    createReviewLearning(input: z.input<typeof CreateLearningCommandInputSchema>, clientRequestId: string) {
      return create(input, clientRequestId, true);
    },

    async completeLearning(
      input: z.input<typeof CompleteLearningInputSchema>,
      expectedVersion: number,
      clientRequestId: string,
    ) {
      const value = CompleteLearningInputSchema.parse(input);
      const version = z.number().int().positive().parse(expectedVersion);
      const context = await createCommandContext("CompleteLearning", clientRequestId, dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("complete_learning_exact", {
        p_verified_user_id: context.user.sub,
        p_client_request_id: context.clientRequestId,
        p_learning_id: value.learningId,
        p_expected_version: version,
        p_completed_at: value.completedAt,
        p_duration_minutes: value.durationMinutes ?? null,
        p_takeaway: value.takeaway ?? null,
        p_practice_result: value.practiceResult ?? null,
        p_learning_outcome: value.learningOutcome,
        p_knowledge_mastery: value.knowledgeMastery,
      });
      if (error) throwDomainCommandError(error, {
        entityType: "Learning", expectedVersion: version, fallback: "Learning could not be completed",
      });
      return rowFrom(data);
    },

    async deleteLearning(
      input: z.input<typeof deleteLearningInputSchema>,
      expectedVersion: number,
      clientRequestId: string,
    ) {
      const value = deleteLearningInputSchema.parse(input);
      const version = z.number().int().positive().parse(expectedVersion);
      const context = await createCommandContext("DeleteLearning", clientRequestId, dependencies.authClient);
      const { data, error } = await dependencies.serviceClient.rpc("delete_learning", {
        p_verified_user_id: context.user.sub,
        p_client_request_id: context.clientRequestId,
        p_learning_id: value.learningId,
        p_expected_version: version,
      });
      if (error) throwDomainCommandError(error, {
        entityType: "Learning", expectedVersion: version, fallback: "Learning could not be deleted",
      });
      return rowFrom(data);
    },
  };
}

async function defaultActions() {
  return createLearningActions({
    authClient: await createServerClient(),
    serviceClient: createServiceRoleClient(),
  });
}

export async function createLearning(input: z.input<typeof CreateLearningCommandInputSchema>, clientRequestId: string) {
  return (await defaultActions()).createLearning(input, clientRequestId);
}

export async function createReviewLearning(input: z.input<typeof CreateLearningCommandInputSchema>, clientRequestId: string) {
  return (await defaultActions()).createReviewLearning(input, clientRequestId);
}

export async function completeLearning(
  input: z.input<typeof CompleteLearningInputSchema>,
  expectedVersion: number,
  clientRequestId: string,
) {
  return (await defaultActions()).completeLearning(input, expectedVersion, clientRequestId);
}

export async function deleteLearning(
  input: z.input<typeof deleteLearningInputSchema>,
  expectedVersion: number,
  clientRequestId: string,
) {
  return (await defaultActions()).deleteLearning(input, expectedVersion, clientRequestId);
}
