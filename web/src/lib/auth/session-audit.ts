import "server-only";
import { z } from "zod";
import { writeAuditLog, type AuditEntry } from "@/lib/audit/audit";

const userIdSchema = z.uuid();

type Credentials = {
  email: string;
  password: string;
};

type AuthApi = {
  signInWithPassword(credentials: Credentials): Promise<{ error: unknown | null }>;
  getClaims(): Promise<{
    data: { claims?: { sub?: string } | null } | null;
    error: unknown | null;
  }>;
  signOut(): Promise<{ error?: unknown | null } | void>;
};

type AuditWriter = (
  context: { user: { sub: string } },
  entry: AuditEntry,
) => Promise<unknown>;

type ClearLocalSession = () => Promise<unknown> | unknown;

async function rollbackSession(auth: AuthApi, clearLocalSession: ClearLocalSession) {
  try {
    await auth.signOut();
  } catch {
    // Local invalidation below is authoritative for the current browser response.
  } finally {
    await clearLocalSession();
  }
}

export async function signInWithAudit(
  credentials: Credentials,
  dependencies: {
    auth: AuthApi;
    auditWriter?: AuditWriter;
    clearLocalSession: ClearLocalSession;
  },
) {
  let signInResult: { error: unknown | null };
  try {
    signInResult = await dependencies.auth.signInWithPassword(credentials);
  } catch {
    await rollbackSession(dependencies.auth, dependencies.clearLocalSession);
    return { ok: false as const, reason: "authentication_failed" as const };
  }

  const { error } = signInResult;
  if (error) return { ok: false as const, reason: "invalid_credentials" as const };

  let claimsResult: Awaited<ReturnType<AuthApi["getClaims"]>>;
  try {
    claimsResult = await dependencies.auth.getClaims();
  } catch {
    await rollbackSession(dependencies.auth, dependencies.clearLocalSession);
    return { ok: false as const, reason: "session_verification_failed" as const };
  }

  const { data, error: claimsError } = claimsResult;
  const parsedUserId = userIdSchema.safeParse(data?.claims?.sub);
  if (claimsError || !parsedUserId.success) {
    await rollbackSession(dependencies.auth, dependencies.clearLocalSession);
    return { ok: false as const, reason: "session_verification_failed" as const };
  }

  const auditWriter = dependencies.auditWriter ?? writeAuditLog;
  try {
    await auditWriter(
      { user: { sub: parsedUserId.data } },
      {
        action: "SignedIn",
        entityType: "AuthSession",
        changedFields: [],
        metadata: {},
      },
    );
  } catch {
    await rollbackSession(dependencies.auth, dependencies.clearLocalSession);
    return { ok: false as const, reason: "audit_failed" as const };
  }

  return { ok: true as const };
}

export async function signOutWithAudit(dependencies: {
  auth: AuthApi;
  auditWriter?: AuditWriter;
  clearLocalSession: ClearLocalSession;
}) {
  let verifiedUserId: string | undefined;
  try {
    const { data, error } = await dependencies.auth.getClaims();
    const parsedUserId = userIdSchema.safeParse(data?.claims?.sub);
    if (!error && parsedUserId.success) verifiedUserId = parsedUserId.data;
  } catch {
    // Logout remains available when claims verification is temporarily unavailable.
  }

  let remoteSignOutSucceeded = false;
  try {
    const result = await dependencies.auth.signOut();
    remoteSignOutSucceeded = !result?.error;
  } catch {
    remoteSignOutSucceeded = false;
  } finally {
    await dependencies.clearLocalSession();
  }

  let auditWritten = false;
  if (verifiedUserId) {
    try {
      const auditWriter = dependencies.auditWriter ?? writeAuditLog;
      await auditWriter(
        { user: { sub: verifiedUserId } },
        {
          action: "SignedOut",
          entityType: "AuthSession",
          changedFields: [],
          metadata: {},
          result: remoteSignOutSucceeded ? "Success" : "Failed",
          ...(remoteSignOutSucceeded ? {} : { errorCode: "RemoteSignOutFailed" }),
        },
      );
      auditWritten = true;
    } catch {
      // Audit is best-effort after the browser session has already been invalidated.
    }
  }

  return { auditWritten, remoteSignOutSucceeded };
}
