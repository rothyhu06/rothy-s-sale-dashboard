import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { throwDetailRead } from "@/lib/queries/entity-not-found";
import { createServerClient } from "@/lib/supabase/server";

type ReadClient = Pick<SupabaseClient, "from" | "rpc">;
export function createContactQueries(dependencies: { client: ReadClient }) {
  return {
    async listContacts(customerId?: string) {
      let query = dependencies.client.from("contacts").select("id,customer_id,full_name,preferred_name,department,position,preferred_channel,preferred_contact_time,communication_preferences,employment_status,relationship_status,organization_influence,influence_evidence,previous_contact_id,merged_into_id,data_level,classification_reason,created_at,updated_at,version").order("updated_at", { ascending: false });
      if (customerId) query = query.eq("customer_id", z.uuid().parse(customerId));
      const { data, error } = await query;
      if (error) throw new Error("Contacts could not be loaded", { cause: error });
      return data ?? [];
    },
    async getContact(contactId: string) {
      const id = z.uuid().parse(contactId);
      const { data, error } = await dependencies.client.rpc("resolve_contact_detail", { p_contact_id: id });
      throwDetailRead(error, "Contact", "Contact could not be loaded");
      return data;
    },
  };
}
export async function listContacts(customerId?: string) { return createContactQueries({ client: await createServerClient() }).listContacts(customerId); }
export async function getContact(contactId: string) { return createContactQueries({ client: await createServerClient() }).getContact(contactId); }
