import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";
import { throwDetailRead } from "@/lib/queries/entity-not-found";

const continueLearningRowSchema = z.object({
  id: z.uuid(),
  title: z.string(),
  learning_type: z.enum(["Study", "Review", "Practice", "Course", "Product Training", "Case Analysis"]),
  status: z.enum(["Planned", "In Progress"]),
  objective: z.string().nullable(),
  started_at: z.string().nullable(),
  completed_at: z.string().nullable(),
  learning_outcome: z.enum(["Passed", "Needs Practice", "Blocked", "Applied", "Shared"]).nullable(),
  parent_learning_id: z.uuid().nullable(),
  updated_at: z.string(),
  version: z.coerce.number().int().positive(),
});

type LearningQueryClient = Pick<SupabaseClient, "rpc" | "from">;

function mapLearning(row: Record<string, unknown>) {
  return {
    id: String(row.id), title: String(row.title), learningType: String(row.learning_type), status: String(row.status),
    objective: row.objective as string | null, startedAt: row.started_at as string | null,
    completedAt: row.completed_at as string | null, durationMinutes: row.duration_minutes as number | null,
    takeaway: row.takeaway as string | null, practiceResult: row.practice_result as string | null,
    learningOutcome: row.learning_outcome as string | null, parentLearningId: row.parent_learning_id as string | null,
    dataLevel: String(row.data_level), classificationReason: row.classification_reason as string | null,
    createdAt: String(row.created_at), updatedAt: String(row.updated_at), version: Number(row.version),
  };
}

function throwRead(error: unknown, message: string) {
  if (error) throw new Error(message, { cause: error });
}

export function createLearningQueries(dependencies: { client: LearningQueryClient }) {
  return {
    async listLearning() {
      const { data, error } = await dependencies.client.from("learning")
        .select("id,title,learning_type,status,objective,started_at,completed_at,duration_minutes,takeaway,practice_result,learning_outcome,parent_learning_id,data_level,classification_reason,created_at,updated_at,version")
        .order("updated_at", { ascending: false }).limit(100);
      throwRead(error, "Learning could not be loaded");
      return ((data ?? []) as Record<string, unknown>[]).map(mapLearning);
    },

    async getLearning(learningId: string) {
      const id = z.uuid().parse(learningId);
      const { data, error } = await dependencies.client.from("learning")
        .select("id,title,learning_type,status,objective,started_at,completed_at,duration_minutes,takeaway,practice_result,learning_outcome,parent_learning_id,data_level,classification_reason,created_at,updated_at,version")
        .eq("id", id).single();
      throwDetailRead(error, "Learning", "Learning could not be loaded");
      const row = mapLearning(data as Record<string, unknown>);
      const [linkResult, childResult, parentResult, tagLinkResult, attachmentLinkResult] = await Promise.all([
        dependencies.client.from("learning_knowledge_links").select("knowledge_id,mastery_before,mastery_after").eq("learning_id", id),
        dependencies.client.from("learning").select("id,title,learning_type,status").eq("parent_learning_id", id).order("created_at", { ascending: true }),
        row.parentLearningId
          ? dependencies.client.from("learning").select("id,title,learning_type,status").eq("id", row.parentLearningId).single()
          : Promise.resolve({ data: null, error: null }),
        dependencies.client.from("tag_links").select("tag_id").eq("learning_id", id),
        dependencies.client.from("attachment_links").select("attachment_id").eq("learning_id", id),
      ]);
      throwRead(linkResult.error ?? childResult.error ?? parentResult.error ?? tagLinkResult.error ?? attachmentLinkResult.error, "Learning chain could not be loaded");
      const knowledgeIds = (linkResult.data ?? []).map((link: Record<string, unknown>) => String(link.knowledge_id));
      const tagIds = (tagLinkResult.data ?? []).map((link: Record<string, unknown>) => String(link.tag_id));
      const attachmentIds = (attachmentLinkResult.data ?? []).map((link: Record<string, unknown>) => String(link.attachment_id));
      const [knowledgeResult, tagResult, attachmentResult] = await Promise.all([
        knowledgeIds.length ? dependencies.client.from("knowledge").select("id,title,status").in("id", knowledgeIds) : Promise.resolve({ data: [], error: null }),
        tagIds.length ? dependencies.client.from("tags").select("id,name,data_level").in("id", tagIds) : Promise.resolve({ data: [], error: null }),
        attachmentIds.length ? dependencies.client.from("attachments").select("id,original_filename,file_category,storage_status,data_level").in("id", attachmentIds) : Promise.resolve({ data: [], error: null }),
      ]);
      throwRead(knowledgeResult.error ?? tagResult.error ?? attachmentResult.error, "Learning link targets could not be loaded");
      const knowledgeById = new Map((knowledgeResult.data ?? []).map((knowledge: Record<string, unknown>) => [knowledge.id, knowledge]));
      return {
        ...row,
        knowledgeLinks: (linkResult.data ?? []).map((link: Record<string, unknown>) => ({
          knowledgeId: link.knowledge_id, masteryBefore: link.mastery_before, masteryAfter: link.mastery_after, knowledge: knowledgeById.get(link.knowledge_id),
        })),
        children: childResult.data ?? [], parent: parentResult.data,
        tags: tagResult.data ?? [], attachments: attachmentResult.data ?? [],
      };
    },
    async getLearningSupport() {
      const [tagResult, attachmentResult] = await Promise.all([
        dependencies.client.from("tags").select("id,name,data_level").order("name", { ascending: true }),
        dependencies.client.from("attachments").select("id,original_filename,file_category,storage_status,data_level").eq("storage_status", "Available").order("created_at", { ascending: false }),
      ]);
      throwRead(tagResult.error ?? attachmentResult.error, "Learning form options could not be loaded");
      return { tags: tagResult.data ?? [], attachments: attachmentResult.data ?? [] };
    },
    async getContinueLearning(limit = 4) {
      const take = z.number().int().min(1).max(20).parse(limit);
      const { data, error } = await dependencies.client.rpc("get_continue_learning", { p_limit: take });
      if (error) throw new Error("Continue Learning could not be loaded", { cause: error });
      return z.array(continueLearningRowSchema).parse(data ?? []).map((row) => ({
        id: row.id,
        title: row.title,
        learningType: row.learning_type,
        status: row.status,
        objective: row.objective,
        startedAt: row.started_at,
        completedAt: row.completed_at,
        learningOutcome: row.learning_outcome,
        parentLearningId: row.parent_learning_id,
        updatedAt: row.updated_at,
        version: row.version,
      }));
    },
  };
}

export async function getContinueLearning(limit = 4) {
  return createLearningQueries({ client: await createServerClient() }).getContinueLearning(limit);
}

export async function listLearning() {
  return createLearningQueries({ client: await createServerClient() }).listLearning();
}
export async function getLearning(learningId: string) {
  return createLearningQueries({ client: await createServerClient() }).getLearning(learningId);
}
export async function getLearningSupport() {
  return createLearningQueries({ client: await createServerClient() }).getLearningSupport();
}
