import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";

type ReadClient = Pick<SupabaseClient, "rpc">;
const optionsSchema = z.object({ asOf: z.coerce.date(), stalledAfterDays: z.number().int().min(1).max(3650) }).strict();

export function createOpportunityQueries(dependencies: { client: ReadClient }) {
  return {
    async getOpportunityProjection(opportunityId: string, options: z.input<typeof optionsSchema>) {
      const id = z.uuid().parse(opportunityId); const v = optionsSchema.parse(options);
      const { data, error } = await dependencies.client.rpc("get_opportunity_projection", {
        p_opportunity_id: id, p_as_of: v.asOf.toISOString(), p_stalled_after_days: v.stalledAfterDays,
      });
      if (error) throw new Error("Opportunity projection could not be loaded", { cause: error });
      return Array.isArray(data) ? data[0] ?? null : data;
    },
  };
}
export async function getOpportunityProjection(id: string, options: z.input<typeof optionsSchema>) {
  return createOpportunityQueries({ client: await createServerClient() }).getOpportunityProjection(id, options);
}
