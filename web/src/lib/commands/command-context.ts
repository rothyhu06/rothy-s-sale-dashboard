import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUser } from "@/lib/auth/require-user";

type AuthClient = {
  auth: Pick<SupabaseClient["auth"], "getClaims">;
};

const commandTypeSchema = z
  .string()
  .regex(/^[A-Z][A-Za-z0-9]{0,99}$/, "commandType must be a stable PascalCase identifier");
const clientRequestIdSchema = z.uuid("clientRequestId must be a UUID");

export async function createCommandContext(
  commandType: string,
  clientRequestId: string,
  client?: AuthClient,
) {
  commandTypeSchema.parse(commandType);
  clientRequestIdSchema.parse(clientRequestId);

  const user = await requireUser(client);

  return {
    user,
    operationId: crypto.randomUUID(),
  };
}
