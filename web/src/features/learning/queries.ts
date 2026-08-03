import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";

const continueLearningRowSchema = z.object({
  id: z.uuid(),
  title: z.string(),
  learning_type: z.enum(["Study", "Review", "Practice", "Course", "Product Training", "Case Analysis"]),
  status: z.enum(["Planned", "In Progress"]),
  objective: z.string().nullable(),
  started_at: z.string().nullable(),
  updated_at: z.string(),
  version: z.coerce.number().int().positive(),
});

type LearningQueryClient = Pick<SupabaseClient, "from">;

export function createLearningQueries(dependencies: { client: LearningQueryClient }) {
  return {
    async getContinueLearning(limit = 4) {
      const take = z.number().int().min(1).max(20).parse(limit);
      const { data, error } = await dependencies.client
        .from("learning")
        .select("id, title, learning_type, status, objective, started_at, updated_at, version")
        .in("status", ["In Progress", "Planned"])
        .order("updated_at", { ascending: false })
        .limit(take);
      if (error) throw new Error("Continue Learning could not be loaded", { cause: error });
      return z.array(continueLearningRowSchema).parse(data ?? []).map((row) => ({
        id: row.id,
        title: row.title,
        learningType: row.learning_type,
        status: row.status,
        objective: row.objective,
        startedAt: row.started_at,
        updatedAt: row.updated_at,
        version: row.version,
      }));
    },
  };
}

export async function getContinueLearning(limit = 4) {
  return createLearningQueries({ client: await createServerClient() }).getContinueLearning(limit);
}
