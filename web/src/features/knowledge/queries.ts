import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";
import { throwDetailRead } from "@/lib/queries/entity-not-found";

const searchRowSchema = z.object({
  source_id: z.uuid(),
  title: z.string(),
  subtitle: z.string().nullable(),
  route: z.string(),
  data_level: z.enum(["Level1", "Level2", "Level3"]),
  metadata: z.record(z.string(), z.unknown()),
});

type SearchClient = Pick<SupabaseClient, "from">;

export type KnowledgeSummary = {
  id: string; title: string; knowledgeType: string; status: string; confidence: string;
  sourceType: string; summary: string | null; contentPlaintext: string; dataLevel: string;
  updatedAt: string; version: number;
};

function mapKnowledge(row: Record<string, unknown>) {
  return {
    id: String(row.id), title: String(row.title), knowledgeType: String(row.knowledge_type),
    status: String(row.status), confidence: String(row.confidence), sourceType: String(row.source_type),
    sourceName: row.source_name as string | null, sourceUrl: row.source_url as string | null,
    summary: row.summary as string | null, technicalPrinciple: row.technical_principle as string | null,
    businessValue: row.business_value as string | null, educationScenario: row.education_scenario as string | null,
    customerPainPoint: row.customer_pain_point as string | null, salesExpression: row.sales_expression as string | null,
    customerQuestions: row.customer_questions as string | null, competitiveNote: row.competitive_note as string | null,
    contentBlocks: row.content_blocks, contentPlaintext: String(row.content_plaintext ?? ""),
    dataLevel: String(row.data_level), classificationReason: row.classification_reason as string | null,
    createdAt: String(row.created_at), updatedAt: String(row.updated_at), version: Number(row.version),
  };
}

function throwRead(error: unknown, message: string) {
  if (error) throw new Error(message, { cause: error });
}

function escapeLikePattern(value: string) {
  return value.replace(/\\/g, "\\\\").replace(/%/g, "\\%").replace(/_/g, "\\_");
}

export function createKnowledgeQueries(dependencies: { client: SearchClient }) {
  return {
    async listKnowledge() {
      const { data, error } = await dependencies.client.from("knowledge")
        .select("id,title,knowledge_type,status,confidence,source_type,source_name,source_url,summary,technical_principle,business_value,education_scenario,customer_pain_point,sales_expression,customer_questions,competitive_note,content_blocks,content_plaintext,data_level,classification_reason,created_at,updated_at,version")
        .order("updated_at", { ascending: false });
      throwRead(error, "Knowledge could not be loaded");
      return ((data ?? []) as Record<string, unknown>[]).map(mapKnowledge);
    },

    async getKnowledge(knowledgeId: string) {
      const id = z.uuid().parse(knowledgeId);
      const { data, error } = await dependencies.client.from("knowledge")
        .select("id,title,knowledge_type,status,confidence,source_type,source_name,source_url,summary,technical_principle,business_value,education_scenario,customer_pain_point,sales_expression,customer_questions,competitive_note,content_blocks,content_plaintext,data_level,classification_reason,created_at,updated_at,version")
        .eq("id", id).single();
      throwDetailRead(error, "Knowledge", "Knowledge could not be loaded");
      const [tagLinkResult, attachmentLinkResult, relationResult] = await Promise.all([
        dependencies.client.from("tag_links").select("tag_id").eq("knowledge_id", id),
        dependencies.client.from("attachment_links").select("attachment_id").eq("knowledge_id", id),
        dependencies.client.from("knowledge_relations").select("related_knowledge_id,relation_type").eq("knowledge_id", id),
      ]);
      throwRead(tagLinkResult.error ?? attachmentLinkResult.error ?? relationResult.error, "Knowledge links could not be loaded");
      const tagIds = (tagLinkResult.data ?? []).map((row: Record<string, unknown>) => String(row.tag_id));
      const attachmentIds = (attachmentLinkResult.data ?? []).map((row: Record<string, unknown>) => String(row.attachment_id));
      const relationIds = (relationResult.data ?? []).map((row: Record<string, unknown>) => String(row.related_knowledge_id));
      const [tagResult, attachmentResult, relatedResult] = await Promise.all([
        tagIds.length ? dependencies.client.from("tags").select("id,name,data_level").in("id", tagIds) : Promise.resolve({ data: [], error: null }),
        attachmentIds.length ? dependencies.client.from("attachments").select("id,original_filename,file_category,storage_status,data_level").in("id", attachmentIds) : Promise.resolve({ data: [], error: null }),
        relationIds.length ? dependencies.client.from("knowledge").select("id,title,status").in("id", relationIds) : Promise.resolve({ data: [], error: null }),
      ]);
      throwRead(tagResult.error ?? attachmentResult.error ?? relatedResult.error, "Knowledge link targets could not be loaded");
      const relatedById = new Map((relatedResult.data ?? []).map((row: Record<string, unknown>) => [row.id, row]));
      return {
        ...mapKnowledge(data as Record<string, unknown>),
        tags: tagResult.data ?? [],
        attachments: attachmentResult.data ?? [],
        relations: (relationResult.data ?? []).map((row: Record<string, unknown>) => ({
          relatedKnowledgeId: String(row.related_knowledge_id), relationType: String(row.relation_type), knowledge: relatedById.get(row.related_knowledge_id),
        })),
      };
    },

    async getKnowledgeSupport() {
      const [tagResult, attachmentResult, knowledgeResult] = await Promise.all([
        dependencies.client.from("tags").select("id,name,data_level").order("name", { ascending: true }),
        dependencies.client.from("attachments").select("id,original_filename,file_category,storage_status,data_level").eq("storage_status", "Available").order("created_at", { ascending: false }),
        dependencies.client.from("knowledge").select("id,title,status,data_level").order("title", { ascending: true }),
      ]);
      throwRead(tagResult.error ?? attachmentResult.error ?? knowledgeResult.error, "Knowledge form options could not be loaded");
      return { tags: tagResult.data ?? [], attachments: attachmentResult.data ?? [], knowledge: knowledgeResult.data ?? [] };
    },

    async searchKnowledge(searchTerm: string, limit = 20) {
      const term = z.string().trim().min(1).max(200).parse(searchTerm).normalize("NFKC");
      const take = z.number().int().min(1).max(50).parse(limit);
      const { data, error } = await dependencies.client
        .from("search_documents")
        .select("source_id, title, subtitle, route, data_level, metadata")
        .eq("source_type", "Knowledge")
        .ilike("search_text", `%${escapeLikePattern(term)}%`)
        .order("source_updated_at", { ascending: false })
        .limit(take);
      if (error) throw new Error("Knowledge search could not be completed", { cause: error });
      return z.array(searchRowSchema).parse(data ?? []).map((row) => ({
        knowledgeId: row.source_id,
        title: row.title,
        subtitle: row.subtitle,
        route: row.route,
        dataLevel: row.data_level,
        metadata: row.metadata,
      }));
    },
  };
}

export async function searchKnowledge(searchTerm: string, limit = 20) {
  return createKnowledgeQueries({ client: await createServerClient() }).searchKnowledge(searchTerm, limit);
}

export async function listKnowledge() {
  return createKnowledgeQueries({ client: await createServerClient() }).listKnowledge();
}
export async function getKnowledge(knowledgeId: string) {
  return createKnowledgeQueries({ client: await createServerClient() }).getKnowledge(knowledgeId);
}
export async function getKnowledgeSupport() {
  return createKnowledgeQueries({ client: await createServerClient() }).getKnowledgeSupport();
}
