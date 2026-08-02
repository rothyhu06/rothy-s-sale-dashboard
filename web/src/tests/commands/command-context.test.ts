import { describe, expect, it, vi } from "vitest";
import { createCommandContext } from "@/lib/commands/command-context";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const receiptId = "7738b1f3-760a-49b0-bb86-f7f9ed51784c";
const operationId = "60d74e72-8209-42df-ab94-eace52caf1b3";

function dependencies(
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
  const claims = { sub: ownerId, email: "owner@example.test" };
  const authClient = {
    auth: {
      getClaims: vi.fn().mockResolvedValue({ data: { claims }, error: null }),
    },
  };
  const receiptClient = {
    rpc: vi.fn().mockResolvedValue({ data: [receipt], error: null }),
  };

  return { claims, authClient, receiptClient };
}

describe("createCommandContext", () => {
  it("claims a receipt for the verified owner and returns its stable operation id", async () => {
    const deps = dependencies();

    const context = await createCommandContext(
      "CreateCustomer",
      "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f",
      deps,
    );

    expect(context).toEqual({
      user: deps.claims,
      receiptId,
      operationId,
      status: "Processing",
      resultReference: null,
    });
    expect(deps.receiptClient.rpc).toHaveBeenCalledWith("claim_command_receipt", {
      p_verified_user_id: ownerId,
      p_command_type: "CreateCustomer",
      p_client_request_id: "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f",
    });
  });

  it("returns the original lightweight result when a completed command is retried", async () => {
    const resultReference = { entityType: "Customer", entityId: "customer-123" };
    const deps = dependencies({
      id: receiptId,
      operation_id: operationId,
      status: "Completed",
      result_reference: resultReference,
    });

    const context = await createCommandContext(
      "CreateCustomer",
      "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f",
      deps,
    );

    expect(context.operationId).toBe(operationId);
    expect(context.status).toBe("Completed");
    expect(context.resultReference).toEqual(resultReference);
  });

  it("fails closed when receipt claiming fails", async () => {
    const deps = dependencies();
    deps.receiptClient.rpc.mockResolvedValue({
      data: null,
      error: new Error("database unavailable"),
    });

    await expect(
      createCommandContext("CreateCustomer", crypto.randomUUID(), deps),
    ).rejects.toThrow("Command receipt could not be claimed");
  });

  it.each([
    ["", "commandType"],
    ["Create Customer", "commandType"],
    ["CreateCustomer", "clientRequestId"],
  ])("rejects invalid command input %s", async (commandType, expectedField) => {
    const deps = dependencies();

    await expect(
      createCommandContext(
        commandType,
        commandType === "CreateCustomer" ? "not-a-uuid" : crypto.randomUUID(),
        deps,
      ),
    ).rejects.toThrow(expectedField);
    expect(deps.authClient.auth.getClaims).not.toHaveBeenCalled();
    expect(deps.receiptClient.rpc).not.toHaveBeenCalled();
  });
});
