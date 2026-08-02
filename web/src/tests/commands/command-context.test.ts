import { describe, expect, it, vi } from "vitest";
import {
  claimSagaCommand,
  createCommandContext,
  retrySagaCommand,
} from "@/lib/commands/command-context";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const clientRequestId = "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f";
const receiptId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const operationId = "60d74e72-8209-42df-ab94-eace52caf1b3";

function authClient(userId = ownerId) {
  const claims = { sub: userId, email: "owner@example.test" };

  return {
    claims,
    client: {
      auth: {
        getClaims: vi.fn().mockResolvedValue({ data: { claims }, error: null }),
      },
    },
  };
}

function receiptClient(
  receipt: {
    id: string;
    operation_id: string;
    status: "Processing" | "Completed" | "Failed";
    result_reference: Record<string, unknown> | null;
  } = {
    id: receiptId,
    operation_id: operationId,
    status: "Processing",
    result_reference: null,
  },
) {
  return {
    rpc: vi.fn().mockResolvedValue({ data: [receipt], error: null }),
  };
}

describe("createCommandContext", () => {
  it("authenticates and validates a pure database command without claiming a receipt", async () => {
    const auth = authClient();

    const context = await createCommandContext(
      "CreateCustomer",
      clientRequestId,
      auth.client,
    );

    expect(context).toEqual({
      user: auth.claims,
      commandType: "CreateCustomer",
      clientRequestId,
    });
    expect(context).not.toHaveProperty("operationId");
    expect(context).not.toHaveProperty("receiptId");
  });

  it.each([
    ["", "commandType"],
    ["Create Customer", "commandType"],
    ["CreateCustomer", "clientRequestId"],
  ])("rejects invalid command input %s", async (commandType, expectedField) => {
    const auth = authClient();

    await expect(
      createCommandContext(
        commandType,
        commandType === "CreateCustomer" ? "not-a-uuid" : crypto.randomUUID(),
        auth.client,
      ),
    ).rejects.toThrow(expectedField);
    expect(auth.client.auth.getClaims).not.toHaveBeenCalled();
  });
});

describe("claimSagaCommand", () => {
  it("uses the explicitly Saga-only RPC and returns its stable operation id", async () => {
    const auth = authClient();
    const context = await createCommandContext(
      "PrepareAttachmentUpload",
      clientRequestId,
      auth.client,
    );
    const client = receiptClient();

    const receipt = await claimSagaCommand(context, client);

    expect(receipt).toEqual({
      receiptId,
      operationId,
      status: "Processing",
      resultReference: null,
    });
    expect(client.rpc).toHaveBeenCalledWith("claim_saga_command_receipt", {
      p_verified_user_id: ownerId,
      p_command_type: "PrepareAttachmentUpload",
      p_client_request_id: clientRequestId,
    });
  });

  it("replays the original Completed result without inventing an operation id", async () => {
    const resultReference = { entityType: "Attachment", entityId: "attachment-123" };
    const auth = authClient();
    const context = await createCommandContext(
      "PrepareAttachmentUpload",
      clientRequestId,
      auth.client,
    );
    const client = receiptClient({
      id: receiptId,
      operation_id: operationId,
      status: "Completed",
      result_reference: resultReference,
    });

    await expect(claimSagaCommand(context, client)).resolves.toEqual({
      receiptId,
      operationId,
      status: "Completed",
      resultReference,
    });
  });

  it("fails closed when Saga receipt claiming fails", async () => {
    const auth = authClient();
    const context = await createCommandContext(
      "PrepareAttachmentUpload",
      clientRequestId,
      auth.client,
    );
    const client = receiptClient();
    client.rpc.mockResolvedValue({ data: null, error: new Error("database unavailable") });

    await expect(claimSagaCommand(context, client)).rejects.toThrow(
      "Saga command receipt could not be claimed",
    );
  });
});

describe("retrySagaCommand", () => {
  it("retries the exact Saga idempotency key while preserving receipt identity", async () => {
    const auth = authClient();
    const context = await createCommandContext(
      "DeleteAttachment",
      clientRequestId,
      auth.client,
    );
    const client = receiptClient();

    const retried = await retrySagaCommand(
      context,
      { receiptId, operationId },
      client,
    );

    expect(retried).toEqual({
      receiptId,
      operationId,
      status: "Processing",
      resultReference: null,
    });
    expect(client.rpc).toHaveBeenCalledWith("retry_saga_command_receipt", {
      p_verified_user_id: ownerId,
      p_command_type: "DeleteAttachment",
      p_client_request_id: clientRequestId,
      p_receipt_id: receiptId,
      p_operation_id: operationId,
    });
  });
});
