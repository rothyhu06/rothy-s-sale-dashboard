import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";

type ReadClient = Pick<SupabaseClient, "rpc" | "from">;
const optionsSchema = z.object({ asOf: z.coerce.date(), stalledAfterDays: z.number().int().min(1).max(3650) }).strict();

export function createOpportunityQueries(dependencies: { client: ReadClient }) {
  return {
    async listOpportunities(customerId?: string) {
      let query = dependencies.client.from("opportunities").select("id,customer_id,parent_opportunity_id,name,opportunity_type,source_type,estimated_amount,currency,expected_decision_date,created_at,updated_at,version").order("updated_at", { ascending: false });
      if (customerId) query = query.eq("customer_id", z.uuid().parse(customerId));
      const { data, error } = await query;
      if (error) throw new Error("Opportunities could not be loaded", { cause: error });
      return data ?? [];
    },
    async getOpportunity(opportunityId: string) {
      const id = z.uuid().parse(opportunityId);
      const [entity, history, roles, outcomes] = await Promise.all([
        dependencies.client.from("opportunities").select("*").eq("id", id).single(),
        dependencies.client.from("opportunity_stage_history").select("*").eq("opportunity_id", id).order("recorded_at", { ascending: false }),
        dependencies.client.from("opportunity_contact_roles").select("*").eq("opportunity_id", id),
        dependencies.client.from("opportunity_outcomes").select("*").eq("opportunity_id", id).is("voided_at", null),
      ]);
      if (entity.error) throw new Error("Opportunity could not be loaded", { cause: entity.error });
      return { ...entity.data, history: history.data ?? [], roles: roles.data ?? [], outcomes: outcomes.data ?? [] };
    },
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
export async function listOpportunities(customerId?: string) { return createOpportunityQueries({ client: await createServerClient() }).listOpportunities(customerId); }
export async function getOpportunity(id: string) { return createOpportunityQueries({ client: await createServerClient() }).getOpportunity(id); }
