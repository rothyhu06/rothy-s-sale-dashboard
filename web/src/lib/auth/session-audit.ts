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
  signOut(): Promise<unknown>;
};

type AuditWriter = (
  context: { user: { sub: string } },
  entry: AuditEntry,
) => Promise<unknown>;

export async function signInWithAudit(
  credentials: Credentials,
  dependencies: { auth: AuthApi; auditWriter?: AuditWriter },
) {
  const { error } = await dependencies.auth.signInWithPassword(credentials);
  if (error) return { ok: false as const, reason: "invalid_credentials" as const };

  const { data, error: claimsError } = await dependencies.auth.getClaims();
  const parsedUserId = userIdSchema.safeParse(data?.claims?.sub);
  if (claimsError || !parsedUserId.success) {
    await dependencies.auth.signOut();
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
    await dependencies.auth.signOut();
    return { ok: false as const, reason: "audit_failed" as const };
  }

  return { ok: true as const };
}

export async function signOutWithAudit(dependencies: {
  auth: AuthApi;
  auditWriter?: AuditWriter;
}) {
  const { data, error } = await dependencies.auth.getClaims();
  const parsedUserId = userIdSchema.safeParse(data?.claims?.sub);
  let auditWritten = false;

  if (!error && parsedUserId.success) {
    try {
      const auditWriter = dependencies.auditWriter ?? writeAuditLog;
      await auditWriter(
        { user: { sub: parsedUserId.data } },
        {
          action: "SignedOut",
          entityType: "AuthSession",
          changedFields: [],
          metadata: {},
        },
      );
      auditWritten = true;
    } catch {
      // Logout is intentionally fail-open: session invalidation must still complete.
    }
  }

  await dependencies.auth.signOut();
  return { auditWritten };
}
