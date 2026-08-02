import { beforeEach, describe, expect, it, vi } from "vitest";

const {
  clearCurrentSupabaseSessionCookies,
  createServerClient,
  signInWithAudit,
  signOutWithAudit,
} = vi.hoisted(() => ({
  clearCurrentSupabaseSessionCookies: vi.fn(),
  createServerClient: vi.fn(),
  signInWithAudit: vi.fn(),
  signOutWithAudit: vi.fn(),
}));

vi.mock("@/lib/supabase/server", () => ({ createServerClient }));
vi.mock("@/lib/auth/session-audit", () => ({ signInWithAudit, signOutWithAudit }));
vi.mock("@/lib/auth/session-cookies", () => ({ clearCurrentSupabaseSessionCookies }));

import { signIn, signOut } from "@/app/(public)/login/actions";

describe("login server actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("routes valid credentials through audited sign-in orchestration", async () => {
    const client = { auth: {} };
    createServerClient.mockResolvedValue(client);
    signInWithAudit.mockResolvedValue({ ok: true });
    const formData = new FormData();
    formData.set("email", "owner@example.test");
    formData.set("password", "NeverLogThisPassword!");

    await expect(signIn(formData)).rejects.toMatchObject({
      digest: expect.stringContaining("NEXT_REDIRECT"),
    });

    expect(signInWithAudit).toHaveBeenCalledWith(
      { email: "owner@example.test", password: "NeverLogThisPassword!" },
      {
        auth: client.auth,
        clearLocalSession: clearCurrentSupabaseSessionCookies,
      },
    );
  });

  it("routes logout through audited sign-out orchestration", async () => {
    const client = { auth: {} };
    createServerClient.mockResolvedValue(client);
    signOutWithAudit.mockResolvedValue({ auditWritten: true });

    await expect(signOut()).rejects.toMatchObject({
      digest: expect.stringContaining("NEXT_REDIRECT"),
    });

    expect(signOutWithAudit).toHaveBeenCalledWith({
      auth: client.auth,
      clearLocalSession: clearCurrentSupabaseSessionCookies,
    });
  });
});
