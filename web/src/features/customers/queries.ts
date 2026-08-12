import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { throwDetailRead } from "@/lib/queries/entity-not-found";
import { createServerClient } from "@/lib/supabase/server";
import { normalizeCustomerName } from "./schema";

type ReadClient = Pick<SupabaseClient, "from" | "rpc">;
const duplicateRowSchema = z.object({ id: z.uuid(), name: z.string(), normalized_name: z.string() });
const customerRowSchema = z.object({
  id: z.uuid(), name: z.string(), normalized_name: z.string(), aliases: z.array(z.string()), customer_type: z.string(),
  education_segment: z.string().nullable(), region: z.string().nullable(), website: z.string().nullable(),
  background: z.string().nullable(), business_context: z.string().nullable(), current_technology: z.string().nullable(),
  current_cloud_provider: z.string().nullable(), known_needs: z.string().nullable(), internal_assessment: z.string().nullable(),
  student_count_estimate: z.number().nullable(), faculty_count_estimate: z.number().nullable(), campus_count: z.number().nullable(),
  organization_stats_as_of: z.string().nullable(), organization_stats_source: z.string().nullable(), record_status: z.string(),
  merged_into_id: z.string().nullable(), data_level: z.literal("Level3"), classification_reason: z.string().nullable(),
  created_at: z.string(), updated_at: z.string(), version: z.number(), deleted_at: z.string().nullable(),
});

export function createCustomerQueries(dependencies: { client: ReadClient }) {
  return {
    async findDuplicateWarnings(name: string, excludeCustomerId?: string) {
      const normalized = normalizeCustomerName(z.string().trim().min(1).max(300).parse(name));
      const excluded = excludeCustomerId ? z.uuid().parse(excludeCustomerId) : null;
      const { data, error } = await dependencies.client.rpc("find_customer_duplicate_warnings", {
        p_normalized_name: normalized, p_exclude_customer_id: excluded,
      });
      if (error) throw new Error("Customer duplicate warnings could not be loaded", { cause: error });
      return z.array(duplicateRowSchema).parse(data ?? []).map((row) => ({ id: row.id, name: row.name, normalizedName: row.normalized_name }));
    },
    async listCustomers() {
      const { data, error } = await dependencies.client.from("customers").select("id,name,normalized_name,aliases,customer_type,education_segment,region,website,background,business_context,current_technology,current_cloud_provider,known_needs,internal_assessment,student_count_estimate,faculty_count_estimate,campus_count,organization_stats_as_of,organization_stats_source,record_status,merged_into_id,data_level,classification_reason,created_at,updated_at,version,deleted_at").order("updated_at", { ascending: false });
      if (error) throw new Error("Customers could not be loaded", { cause: error });
      return z.array(customerRowSchema).parse(data ?? []);
    },
    async getCustomer(customerId: string) {
      const id = z.uuid().parse(customerId);
      const { data, error } = await dependencies.client.rpc("resolve_customer_detail", { p_customer_id: id });
      throwDetailRead(error, "Customer", "Customer could not be loaded");
      return data;
    },
  };
}
export async function listCustomers() { return createCustomerQueries({ client: await createServerClient() }).listCustomers(); }
export async function getCustomer(customerId: string) { return createCustomerQueries({ client: await createServerClient() }).getCustomer(customerId); }
