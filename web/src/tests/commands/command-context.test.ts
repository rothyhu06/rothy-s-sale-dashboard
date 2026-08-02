import { describe, expect, it, vi } from "vitest";
import { createCommandContext } from "@/lib/commands/command-context";

function authenticatedClient(userId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc") {
  const claims = { sub: userId, email: "owner@example.test" };

  return {
    claims,
    client: {
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: { claims },
          error: null,
        }),
      },
    },
  };
}

describe("createCommandContext", () => {
  it("authenticates the owner and generates the operation id on the server", async () => {
    const { claims, client } = authenticatedClient();

    const context = await createCommandContext(
      "CreateCustomer",
      "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f",
      client,
    );

    expect(context.user).toBe(claims);
    expect(context.operationId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(client.auth.getClaims).toHaveBeenCalledOnce();
  });

  it("does not reuse a caller-controlled id as the operation id", async () => {
    const clientRequestId = "94dc7703-0b72-44aa-bf05-3ac59b41ae5a";
    const { client } = authenticatedClient();

    const context = await createCommandContext("CreateCustomer", clientRequestId, client);

    expect(context.operationId).not.toBe(clientRequestId);
  });

  it.each([
    ["", "commandType"],
    ["Create Customer", "commandType"],
    ["CreateCustomer", "clientRequestId"],
  ])("rejects invalid command input %s", async (commandType, expectedField) => {
    const { client } = authenticatedClient();

    await expect(
      createCommandContext(commandType, commandType === "CreateCustomer" ? "not-a-uuid" : crypto.randomUUID(), client),
    ).rejects.toThrow(expectedField);
    expect(client.auth.getClaims).not.toHaveBeenCalled();
  });
});
