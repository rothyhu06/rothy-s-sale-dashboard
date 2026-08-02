import "server-only";
import { clearAuthCookiesAtScopes, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { publicEnv } from "@/lib/env/public";

type CookieStore = {
  getAll(): Array<{ name: string; value: string }>;
  set(name: string, value: string, options: CookieOptions): void;
};

export async function clearSupabaseSessionCookies({
  supabaseUrl,
  cookieStore,
}: {
  supabaseUrl: string;
  cookieStore: CookieStore;
}) {
  const hostname = new URL(supabaseUrl).hostname;
  const storageKey = `sb-${hostname.split(".")[0]}-auth-token`;

  await clearAuthCookiesAtScopes({
    getAll: async () => cookieStore.getAll(),
    setAll: async (cookiesToSet) => {
      for (const { name, value, options } of cookiesToSet) {
        cookieStore.set(name, value, options);
      }
    },
    storageKey,
    scopes: [{ path: "/" }],
  });
}

export async function clearCurrentSupabaseSessionCookies() {
  const cookieStore = await cookies();
  const { supabaseUrl } = publicEnv();
  await clearSupabaseSessionCookies({ supabaseUrl, cookieStore });
}
