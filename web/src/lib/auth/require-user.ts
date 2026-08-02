import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { createServerClient } from "@/lib/supabase/server";

type AuthClient = {
  auth: Pick<SupabaseClient["auth"], "getClaims">;
};

export async function requireUser(client?: AuthClient) {
  const supabase = client ?? (await createServerClient());
  const { data, error } = await supabase.auth.getClaims();

  if (error || !data?.claims) {
    redirect("/login");
  }

  return data.claims;
}
