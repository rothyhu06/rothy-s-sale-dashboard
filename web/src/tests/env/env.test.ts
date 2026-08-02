import { describe, expect, it } from "vitest";
import { publicEnv } from "@/lib/env/public";
import { serverEnv } from "@/lib/env/server";

describe("environment readers", () => {
  it("rejects a missing service role key", () => {
    expect(() => serverEnv({})).toThrow("SUPABASE_SERVICE_ROLE_KEY");
  });

  it("returns the public Supabase settings", () => {
    expect(
      publicEnv({
        NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
        NEXT_PUBLIC_SUPABASE_ANON_KEY: "anon",
      }),
    ).toEqual({
      supabaseUrl: "http://127.0.0.1:54321",
      supabaseAnonKey: "anon",
    });
  });
});
