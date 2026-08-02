import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUser } from "@/lib/auth/require-user";
import { createServiceRoleClient } from "@/lib/supabase/service-role";

type AuthClient = {
  auth: Pick<SupabaseClient["auth"], "getClaims">;
};

type RpcClient = Pick<SupabaseClient, "rpc">;

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
  commandType: string;
  clientRequestId: string;
};

export type SagaCommandReceipt = {
  receiptId: string;
  operationId: string;
  status: "Processing" | "Completed" | "Failed";
  resultReference: Record<string, unknown> | null;
};

export async function createCommandContext(
  commandType: string,
  clientRequestId: string,
  authClient?: AuthClient,
): Promise<CommandContext> {
  commandTypeSchema.parse(commandType);
  clientRequestIdSchema.parse(clientRequestId);

  const user = await requireUser(authClient);
  verifiedUserIdSchema.parse(user.sub);

  return { user, commandType, clientRequestId };
}

export async function claimSagaCommand(
  context: CommandContext,
  client?: RpcClient,
): Promise<SagaCommandReceipt> {
  const verifiedUserId = verifiedUserIdSchema.parse(context.user.sub);
  const serviceClient = client ?? createServiceRoleClient();
  const { data, error } = await serviceClient.rpc("claim_saga_command_receipt", {
    p_verified_user_id: verifiedUserId,
    p_command_type: commandTypeSchema.parse(context.commandType),
    p_client_request_id: clientRequestIdSchema.parse(context.clientRequestId),
  });

  if (error) {
    throw new Error("Saga command receipt could not be claimed", { cause: error });
  }

  const receipt = receiptSchema.parse(Array.isArray(data) ? data[0] : data);

  return {
    receiptId: receipt.id,
    operationId: receipt.operation_id,
    status: receipt.status,
    resultReference: receipt.result_reference,
  };
}

export async function retrySagaCommand(
  context: CommandContext,
  receiptIdentity: Pick<SagaCommandReceipt, "receiptId" | "operationId">,
  client?: RpcClient,
): Promise<SagaCommandReceipt> {
  const verifiedUserId = verifiedUserIdSchema.parse(context.user.sub);
  const receiptId = z.uuid().parse(receiptIdentity.receiptId);
  const operationId = z.uuid().parse(receiptIdentity.operationId);
  const serviceClient = client ?? createServiceRoleClient();
  const { data, error } = await serviceClient.rpc("retry_saga_command_receipt", {
    p_verified_user_id: verifiedUserId,
    p_command_type: commandTypeSchema.parse(context.commandType),
    p_client_request_id: clientRequestIdSchema.parse(context.clientRequestId),
    p_receipt_id: receiptId,
    p_operation_id: operationId,
  });

  if (error) {
    throw new Error("Saga command receipt could not be retried", { cause: error });
  }

  const receipt = receiptSchema.parse(Array.isArray(data) ? data[0] : data);

  return {
    receiptId: receipt.id,
    operationId: receipt.operation_id,
    status: receipt.status,
    resultReference: receipt.result_reference,
  };
}
