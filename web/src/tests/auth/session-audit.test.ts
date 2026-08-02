import { describe, expect, it, vi } from "vitest";
import { signInWithAudit, signOutWithAudit } from "@/lib/auth/session-audit";

const userId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const credentials = {
  email: "owner@example.test",
  password: "NeverLogThisPassword!",
};

describe("signInWithAudit", () => {
  it("verifies the new session and writes a sanitized SignedIn audit", async () => {
    const events: string[] = [];
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
    const clearLocalSession = vi.fn();
    const auditWriter = vi.fn(async (context, entry) => {
      events.push("audited");
      expect(JSON.stringify({ context, entry })).not.toContain(credentials.email);
      expect(JSON.stringify({ context, entry })).not.toContain(credentials.password);
      return crypto.randomUUID();
    });

    await expect(
      signInWithAudit(credentials, { auth, auditWriter, clearLocalSession }),
    ).resolves.toEqual({ ok: true });

    expect(events).toEqual(["signed-in", "verified", "audited"]);
    expect(clearLocalSession).not.toHaveBeenCalled();
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

  it("does not audit or clear local cookies for rejected credentials", async () => {
    const auditWriter = vi.fn();
    const clearLocalSession = vi.fn();
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: new Error("invalid") }),
      getClaims: vi.fn(),
      signOut: vi.fn(),
    };

    await expect(
      signInWithAudit(credentials, { auth, auditWriter, clearLocalSession }),
    ).resolves.toEqual({ ok: false, reason: "invalid_credentials" });
    expect(auth.getClaims).not.toHaveBeenCalled();
    expect(clearLocalSession).not.toHaveBeenCalled();
    expect(auditWriter).not.toHaveBeenCalled();
  });

  it("clears local cookies when claims verification throws and remote rollback fails", async () => {
    let hasLocalSessionCookie = true;
    const clearLocalSession = vi.fn(() => {
      hasLocalSessionCookie = false;
    });
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: null }),
      getClaims: vi.fn().mockRejectedValue(new Error("claims unavailable")),
      signOut: vi.fn().mockRejectedValue(new Error("remote rollback unavailable")),
    };

    await expect(
      signInWithAudit(credentials, {
        auth,
        auditWriter: vi.fn(),
        clearLocalSession,
      }),
    ).resolves.toEqual({ ok: false, reason: "session_verification_failed" });
    expect(auth.signOut).toHaveBeenCalledOnce();
    expect(clearLocalSession).toHaveBeenCalledOnce();
    expect(hasLocalSessionCookie).toBe(false);
  });

  it("clears local cookies when claims are invalid and remote rollback returns an error", async () => {
    const clearLocalSession = vi.fn();
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: null }),
      getClaims: vi.fn().mockResolvedValue({
        data: { claims: { sub: "not-a-uuid" } },
        error: null,
      }),
      signOut: vi.fn().mockResolvedValue({ error: new Error("remote rollback failed") }),
    };

    await expect(
      signInWithAudit(credentials, {
        auth,
        auditWriter: vi.fn(),
        clearLocalSession,
      }),
    ).resolves.toEqual({ ok: false, reason: "session_verification_failed" });
    expect(clearLocalSession).toHaveBeenCalledOnce();
  });

  it("clears local cookies when SignedIn audit fails and remote rollback throws", async () => {
    let hasLocalSessionCookie = true;
    const clearLocalSession = vi.fn(() => {
      hasLocalSessionCookie = false;
    });
    const auth = {
      signInWithPassword: vi.fn().mockResolvedValue({ error: null }),
      getClaims: vi.fn().mockResolvedValue({
        data: { claims: { sub: userId } },
        error: null,
      }),
      signOut: vi.fn().mockRejectedValue(new Error("remote rollback unavailable")),
    };

    await expect(
      signInWithAudit(credentials, {
        auth,
        auditWriter: vi.fn().mockRejectedValue(new Error("audit unavailable")),
        clearLocalSession,
      }),
    ).resolves.toEqual({ ok: false, reason: "audit_failed" });
    expect(auth.signOut).toHaveBeenCalledOnce();
    expect(clearLocalSession).toHaveBeenCalledOnce();
    expect(hasLocalSessionCookie).toBe(false);
  });
});

describe("signOutWithAudit", () => {
  it("invalidates remotely and locally before writing a successful SignedOut audit", async () => {
    const events: string[] = [];
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn(async () => {
        events.push("verified");
        return { data: { claims: { sub: userId, email: credentials.email } }, error: null };
      }),
      signOut: vi.fn(async () => {
        events.push("remote-invalidated");
        return { error: null };
      }),
    };
    const clearLocalSession = vi.fn(async () => events.push("local-cleared"));
    const auditWriter = vi.fn(async (context, entry) => {
      events.push("audited");
      expect(JSON.stringify({ context, entry })).not.toContain(credentials.email);
      return crypto.randomUUID();
    });

    await expect(
      signOutWithAudit({ auth, auditWriter, clearLocalSession }),
    ).resolves.toEqual({ auditWritten: true, remoteSignOutSucceeded: true });
    expect(events).toEqual(["verified", "remote-invalidated", "local-cleared", "audited"]);
    expect(auditWriter).toHaveBeenCalledWith(
      { user: { sub: userId } },
      {
        action: "SignedOut",
        entityType: "AuthSession",
        changedFields: [],
        metadata: {},
        result: "Success",
      },
    );
  });

  it("still attempts remote and local invalidation when getClaims throws", async () => {
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn().mockRejectedValue(new Error("claims unavailable")),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    };
    const clearLocalSession = vi.fn();
    const auditWriter = vi.fn();

    await expect(
      signOutWithAudit({ auth, auditWriter, clearLocalSession }),
    ).resolves.toEqual({ auditWritten: false, remoteSignOutSucceeded: true });
    expect(auth.signOut).toHaveBeenCalledOnce();
    expect(clearLocalSession).toHaveBeenCalledOnce();
    expect(auditWriter).not.toHaveBeenCalled();
  });

  it("clears local cookies and audits a remote sign-out error truthfully", async () => {
    const events: string[] = [];
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn().mockResolvedValue({ data: { claims: { sub: userId } }, error: null }),
      signOut: vi.fn(async () => {
        events.push("remote-failed");
        return { error: new Error("sensitive provider details") };
      }),
    };
    const clearLocalSession = vi.fn(async () => events.push("local-cleared"));
    const auditWriter = vi.fn(async (_context, entry) => {
      events.push("audited");
      expect(JSON.stringify(entry)).not.toContain("sensitive provider details");
      return crypto.randomUUID();
    });

    await expect(
      signOutWithAudit({ auth, auditWriter, clearLocalSession }),
    ).resolves.toEqual({ auditWritten: true, remoteSignOutSucceeded: false });
    expect(events).toEqual(["remote-failed", "local-cleared", "audited"]);
    expect(auditWriter).toHaveBeenCalledWith(
      { user: { sub: userId } },
      expect.objectContaining({ result: "Failed", errorCode: "RemoteSignOutFailed" }),
    );
  });

  it("clears local cookies and audits truthfully when remote sign-out throws", async () => {
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn().mockResolvedValue({ data: { claims: { sub: userId } }, error: null }),
      signOut: vi.fn().mockRejectedValue(new Error("remote unavailable")),
    };
    const clearLocalSession = vi.fn();
    const auditWriter = vi.fn().mockResolvedValue(crypto.randomUUID());

    await expect(
      signOutWithAudit({ auth, auditWriter, clearLocalSession }),
    ).resolves.toEqual({ auditWritten: true, remoteSignOutSucceeded: false });
    expect(clearLocalSession).toHaveBeenCalledOnce();
    expect(auditWriter).toHaveBeenCalledWith(
      { user: { sub: userId } },
      expect.objectContaining({ result: "Failed", errorCode: "RemoteSignOutFailed" }),
    );
  });

  it("completes logout when the post-invalidation audit fails", async () => {
    const auth = {
      signInWithPassword: vi.fn(),
      getClaims: vi.fn().mockResolvedValue({ data: { claims: { sub: userId } }, error: null }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    };
    const clearLocalSession = vi.fn();

    await expect(
      signOutWithAudit({
        auth,
        auditWriter: vi.fn().mockRejectedValue(new Error("audit unavailable")),
        clearLocalSession,
      }),
    ).resolves.toEqual({ auditWritten: false, remoteSignOutSucceeded: true });
    expect(clearLocalSession).toHaveBeenCalledOnce();
  });
});
