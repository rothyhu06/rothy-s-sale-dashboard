import { createBrowserClient as createSupabaseBrowserClient } from "@supabase/ssr";
import { publicEnv } from "@/lib/env/public";

export function createBrowserClient() {
  const { supabaseUrl, supabaseAnonKey } = publicEnv();

  return createSupabaseBrowserClient(supabaseUrl, supabaseAnonKey);
}
