import { describe, expect, it, vi } from "vitest";
import { requireUser } from "@/lib/auth/require-user";

function supabaseWithClaims(claims: Record<string, unknown> | null) {
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue({
        data: { claims },
        error: null,
      }),
    },
  };
}

describe("requireUser", () => {
  it("redirects an anonymous request to login", async () => {
    const supabase = supabaseWithClaims(null);

    await expect(requireUser(supabase)).rejects.toMatchObject({
      digest: expect.stringContaining("NEXT_REDIRECT"),
    });
    expect(supabase.auth.getClaims).toHaveBeenCalledOnce();
  });

  it("returns verified claims for an authenticated request", async () => {
    const claims = { sub: "user-123", email: "owner@example.test" };

    await expect(requireUser(supabaseWithClaims(claims))).resolves.toBe(claims);
  });
});
