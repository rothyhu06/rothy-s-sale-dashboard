import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUser } from "@/lib/auth/require-user";
import { createServiceRoleClient } from "@/lib/supabase/service-role";

type AuthClient = {
  auth: Pick<SupabaseClient["auth"], "getClaims">;
};

type RpcClient = Pick<SupabaseClient, "rpc">;

type CommandDependencies = {
  authClient?: AuthClient;
  receiptClient?: RpcClient;
};

const commandTypeSchema = z
  .string()
  .regex(/^[A-Z][A-Za-z0-9]{0,99}$/, "commandType must be a stable PascalCase identifier");
const clientRequestIdSchema = z.uuid("clientRequestId must be a UUID");
const verifiedUserIdSchema = z.uuid("verifiedUserId must be a UUID");
const receiptSchema = z.object({
  id: z.uuid(),
  operation_id: z.uuid(),
  status: z.enum(["Processing", "Completed", "Failed"]),
  result_reference: z.record(z.string(), z.unknown()).nullable(),
});

export type CommandContext = {
  user: Awaited<ReturnType<typeof requireUser>>;
  receiptId: string;
  operationId: string;
  status: "Processing" | "Completed" | "Failed";
  resultReference: Record<string, unknown> | null;
};

export async function createCommandContext(
  commandType: string,
  clientRequestId: string,
  dependencies: CommandDependencies = {},
): Promise<CommandContext> {
  commandTypeSchema.parse(commandType);
  clientRequestIdSchema.parse(clientRequestId);

  const user = await requireUser(dependencies.authClient);
  const verifiedUserId = verifiedUserIdSchema.parse(user.sub);
  const receiptClient = dependencies.receiptClient ?? createServiceRoleClient();
  const { data, error } = await receiptClient.rpc("claim_command_receipt", {
    p_verified_user_id: verifiedUserId,
    p_command_type: commandType,
    p_client_request_id: clientRequestId,
  });

  if (error) {
    throw new Error("Command receipt could not be claimed", { cause: error });
  }

  const receipt = receiptSchema.parse(Array.isArray(data) ? data[0] : data);

  return {
    user,
    receiptId: receipt.id,
    operationId: receipt.operation_id,
    status: receipt.status,
    resultReference: receipt.result_reference,
  };
}
