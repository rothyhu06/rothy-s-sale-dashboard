import { describe, expect, it } from "vitest";
import { requireLocalSupabaseUrl } from "../../../e2e/support/local-supabase";

describe("requireLocalSupabaseUrl", () => {
  it.each([
    "http://127.0.0.1:54321",
    "http://localhost:54321",
    "http://[::1]:54321",
  ])("accepts the approved loopback URL %s", (value) => {
    expect(requireLocalSupabaseUrl(value).href).toBe(`${value}/`);
  });

  it.each([
    "https://supabase.example.com",
    "http://localhost.attacker.example:54321",
    "http://localhost@attacker.example:54321",
  ])("rejects the non-local URL %s", (value) => {
    expect(() => requireLocalSupabaseUrl(value)).toThrow("local Supabase URL");
  });

  it.each([undefined, "not a url"])("rejects an absent or invalid URL", (value) => {
    expect(() => requireLocalSupabaseUrl(value)).toThrow("local Supabase URL");
  });
});
