import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";

const searchRowSchema = z.object({
  source_id: z.uuid(),
  title: z.string(),
  subtitle: z.string().nullable(),
  route: z.string(),
  data_level: z.enum(["Level1", "Level2", "Level3"]),
  metadata: z.record(z.string(), z.unknown()),
});

type SearchClient = Pick<SupabaseClient, "from">;

function escapeLikePattern(value: string) {
  return value.replace(/\\/g, "\\\\").replace(/%/g, "\\%").replace(/_/g, "\\_");
}

export function createKnowledgeQueries(dependencies: { client: SearchClient }) {
  return {
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
