import { describe, expect, it, vi } from "vitest";
import { signInWithAudit, signOutWithAudit } from "@/lib/auth/session-audit";

describe("signInWithAudit", () => {
  it("verifies the new session and writes a sanitized SignedIn audit", async () => {
    const events: string[] = [];
    const credentials = {
      email: "owner@example.test",
      password: "NeverLogThisPassword!",
    };
    const userId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
    const auth = {
      signInWithPassword: vi.fn(async () => {
        events.push("signed-in");
        return { error: null };
      }),
      getClaims: vi.fn(async () => {
        events.push("verified");
        return { data: { claims: { sub: userId, email: credentials.email } }, error: null };
      }),
      signOut: vi.fn(),
    };
    const auditWriter = vi.fn(async (context, entry) => {
      events.push("audited");
      expect(JSON.stringify({ context, entry })).not.toContain(credentials.email);
      expect(JSON.stringify({ context, entry })).not.toContain(credentials.password);
      return crypto.randomUUID();
    });

    await expect(signInWithAudit(credentials, { auth, auditWriter })).resolves.toEqual({
      ok: true,
    });

    expect(events).toEqual(["signed-in", "verified", "audited"]);
    expect(auditWriter).toHaveBeenCalledWith(
      { user: { sub: userId } },
      {
        action: "SignedIn",
        entityType: "AuthSession",
        changedFields: [],
        metadata: {},
      },
    );
  });

  it("does not audit rejected credentials", async () => {
    const auditWriter = vi.fn();
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: new Error("invalid") }),
      getClaims: vi.fn(),
      signOut: vi.fn(),
    };

    await expect(
      signInWithAudit(
        { email: "owner@example.test", password: "bad-password" },
        { auth, auditWriter },
      ),
    ).resolves.toEqual({ ok: false, reason: "invalid_credentials" });
    expect(auth.getClaims).not.toHaveBeenCalled();
    expect(auditWriter).not.toHaveBeenCalled();
  });

  it("revokes an unverified session without writing an audit", async () => {
    const auditWriter = vi.fn();
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: null }),
      getClaims: vi.fn().mockResolvedValue({
        data: { claims: { sub: "not-a-uuid" } },
        error: null,
      }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    };

    await expect(
      signInWithAudit(
        { email: "owner@example.test", password: "not-logged" },
        { auth, auditWriter },
      ),
    ).resolves.toEqual({ ok: false, reason: "session_verification_failed" });
    expect(auth.signOut).toHaveBeenCalledOnce();
    expect(auditWriter).not.toHaveBeenCalled();
  });

  it("fails closed and revokes the session when SignedIn audit writing fails", async () => {
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: null }),
      getClaims: vi.fn().mockResolvedValue({
        data: { claims: { sub: "937c8b0a-7c21-4604-a428-0a9523bbb3fc" } },
        error: null,
      }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    };

    await expect(
      signInWithAudit(
        { email: "owner@example.test", password: "not-logged" },
        { auth, auditWriter: vi.fn().mockRejectedValue(new Error("audit unavailable")) },
      ),
    ).resolves.toEqual({ ok: false, reason: "audit_failed" });
    expect(auth.signOut).toHaveBeenCalledOnce();
  });
});

describe("signOutWithAudit", () => {
  const userId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";

  it("writes SignedOut before invalidating the verified session", async () => {
    const events: string[] = [];
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn(async () => ({
        data: { claims: { sub: userId, email: "owner@example.test" } },
        error: null,
      })),
      signOut: vi.fn(async () => {
        events.push("signed-out");
        return { error: null };
      }),
    };
    const auditWriter = vi.fn(async (context, entry) => {
      events.push("audited");
      expect(JSON.stringify({ context, entry })).not.toContain("owner@example.test");
      return crypto.randomUUID();
    });

    await expect(signOutWithAudit({ auth, auditWriter })).resolves.toEqual({
      auditWritten: true,
    });
    expect(events).toEqual(["audited", "signed-out"]);
    expect(auditWriter).toHaveBeenCalledWith(
      { user: { sub: userId } },
      {
        action: "SignedOut",
        entityType: "AuthSession",
        changedFields: [],
        metadata: {},
      },
    );
  });

  it("still invalidates the session when SignedOut audit writing fails", async () => {
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn().mockResolvedValue({
        data: { claims: { sub: userId } },
        error: null,
      }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    };

    await expect(
      signOutWithAudit({
        auth,
        auditWriter: vi.fn().mockRejectedValue(new Error("audit unavailable")),
      }),
    ).resolves.toEqual({ auditWritten: false });
    expect(auth.signOut).toHaveBeenCalledOnce();
  });
});
