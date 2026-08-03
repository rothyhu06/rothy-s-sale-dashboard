import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createCommandContext } from "@/lib/commands/command-context";
import {
  validateAttachmentReferences,
  type AttachmentReferenceRepository,
} from "@/lib/content-blocks/attachment-references";
import { VersionConflictError, throwDomainCommandError } from "@/lib/commands/version-conflict";
import { createServerClient } from "@/lib/supabase/server";
import { createServiceRoleClient } from "@/lib/supabase/service-role";
import { CreateKnowledgeInputSchema } from "./schema";

export { VersionConflictError };

const relationSchema = z.object({
  relatedKnowledgeId: z.uuid(),
  relationType: z.string().trim().min(1).max(80),
}).strict();

export const CreateKnowledgeCommandInputSchema = CreateKnowledgeInputSchema.safeExtend({
  tagIds: z.array(z.uuid()).max(100).default([]),
  relations: z.array(relationSchema).max(100).default([]),
});

export const UpdateKnowledgeCommandInputSchema = CreateKnowledgeCommandInputSchema.safeExtend({
  knowledgeId: z.uuid(),
});

const knowledgeRowSchema = z.object({
  id: z.uuid(),
  title: z.string(),
  content_plaintext: z.string(),
  data_level: z.enum(["Level1", "Level2", "Level3"]),
  version: z.coerce.number().int().positive(),
  operation_id: z.uuid(),
});

type RpcClient = Pick<SupabaseClient, "rpc">;
type KnowledgeDependencies = {
  authClient: Parameters<typeof createCommandContext>[2];
  serviceClient: RpcClient;
  attachmentRepository: AttachmentReferenceRepository;
};

function rowFrom(data: unknown) {
  const row = knowledgeRowSchema.parse(Array.isArray(data) ? data[0] : data);
  return {
    id: row.id,
    title: row.title,
    contentPlaintext: row.content_plaintext,
    dataLevel: row.data_level,
    version: row.version,
    operationId: row.operation_id,
  };
}

function commandParams(
  value: z.infer<typeof CreateKnowledgeCommandInputSchema>,
  ownerId: string,
  clientRequestId: string,
  effectiveDataLevel: "Level1" | "Level2" | "Level3",
  attachmentIds: string[],
) {
  return {
    p_verified_user_id: ownerId,
    p_client_request_id: clientRequestId,
    p_title: value.title,
    p_knowledge_type: value.knowledgeType,
    p_status: value.status,
    p_confidence: value.confidence,
    p_source_type: value.sourceType,
    p_source_name: value.sourceName ?? null,
    p_source_url: value.sourceUrl ?? null,
    p_summary: value.summary ?? null,
    p_technical_principle: value.technicalPrinciple ?? null,
    p_business_value: value.businessValue ?? null,
    p_education_scenario: value.educationScenario ?? null,
    p_customer_pain_point: value.customerPainPoint ?? null,
    p_sales_expression: value.salesExpression ?? null,
    p_customer_questions: value.customerQuestions ?? null,
    p_competitive_note: value.competitiveNote ?? null,
    p_content_blocks: value.contentBlocks,
    p_data_level: effectiveDataLevel,
    p_classification_reason: value.classificationReason ?? null,
    p_attachment_ids: attachmentIds,
    p_tag_ids: value.tagIds,
    p_relations: value.relations,
  };
}

export function createKnowledgeActions(dependencies: KnowledgeDependencies) {
  async function validateAttachments(
    value: z.infer<typeof CreateKnowledgeCommandInputSchema>,
    ownerId: string,
  ) {
    return validateAttachmentReferences(value.contentBlocks, {
      ownerId,
      baseDataLevel: value.dataLevel,
      repository: dependencies.attachmentRepository,
    });
  }

  return {
    async createKnowledge(input: z.input<typeof CreateKnowledgeCommandInputSchema>, clientRequestId: string) {
      const value = CreateKnowledgeCommandInputSchema.parse(input);
      const context = await createCommandContext("CreateKnowledge", clientRequestId, dependencies.authClient);
      const validated = await validateAttachments(value, context.user.sub);
      const { data, error } = await dependencies.serviceClient.rpc("create_knowledge", commandParams(
        value, context.user.sub, context.clientRequestId, validated.effectiveDataLevel, validated.attachmentIds,
      ));
      if (error) throwDomainCommandError(error, { entityType: "Knowledge", fallback: "Knowledge could not be created" });
      return rowFrom(data);
    },

    async updateKnowledge(
      input: z.input<typeof UpdateKnowledgeCommandInputSchema>,
      expectedVersion: number,
      clientRequestId: string,
    ) {
      const value = UpdateKnowledgeCommandInputSchema.parse(input);
      const version = z.number().int().positive().parse(expectedVersion);
      const context = await createCommandContext("UpdateKnowledge", clientRequestId, dependencies.authClient);
      const validated = await validateAttachments(value, context.user.sub);
      const { data, error } = await dependencies.serviceClient.rpc("update_knowledge", {
        ...commandParams(value, context.user.sub, context.clientRequestId, validated.effectiveDataLevel, validated.attachmentIds),
        p_knowledge_id: value.knowledgeId,
        p_expected_version: version,
      });
      if (error) throwDomainCommandError(error, {
        entityType: "Knowledge", expectedVersion: version, fallback: "Knowledge could not be updated",
      });
      return rowFrom(data);
    },
  };
}

function attachmentRepository(client: SupabaseClient): AttachmentReferenceRepository {
  return {
    async findByIds(ownerId, ids) {
      const { data, error } = await client
        .from("attachments")
        .select("id, owner_id, storage_status, deleted_at, file_category, data_level")
        .eq("owner_id", ownerId)
        .in("id", ids);
      if (error) throw new Error("Attachment references could not be validated", { cause: error });
      return data ?? [];
    },
  };
}

async function defaultActions() {
  const serviceClient = createServiceRoleClient();
  return createKnowledgeActions({
    authClient: await createServerClient(),
    serviceClient,
    attachmentRepository: attachmentRepository(serviceClient),
  });
}

export async function createKnowledge(input: z.input<typeof CreateKnowledgeCommandInputSchema>, clientRequestId: string) {
  return (await defaultActions()).createKnowledge(input, clientRequestId);
}

export async function updateKnowledge(
  input: z.input<typeof UpdateKnowledgeCommandInputSchema>,
  expectedVersion: number,
  clientRequestId: string,
) {
  return (await defaultActions()).updateKnowledge(input, expectedVersion, clientRequestId);
}
