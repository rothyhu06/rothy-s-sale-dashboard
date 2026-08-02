import { describe, expect, it, vi } from "vitest";
import { clearSupabaseSessionCookies } from "@/lib/auth/session-cookies";

describe("clearSupabaseSessionCookies", () => {
  it("expires only the Supabase auth cookie and its chunks", async () => {
    const set = vi.fn();
    const cookieStore = {
      getAll: vi.fn(() => [
        { name: "unrelated-preference", value: "keep-me" },
        { name: "sb-127-auth-token.0", value: "session-part-a" },
        { name: "sb-127-auth-token.1", value: "session-part-b" },
        { name: "sb-another-auth-token", value: "other-project" },
      ]),
      set,
    };

    await clearSupabaseSessionCookies({
      supabaseUrl: "http://127.0.0.1:54321",
      cookieStore,
    });

    expect(set.mock.calls.map(([name]) => name)).toEqual([
      "sb-127-auth-token.0",
      "sb-127-auth-token.1",
    ]);
    for (const [, value, options] of set.mock.calls) {
      expect(value).toBe("");
      expect(options).toEqual(expect.objectContaining({ maxAge: 0, path: "/" }));
    }
  });
});
