import { describe, expect, it, vi } from "vitest";
import { writeAuditLog } from "@/lib/audit/audit";

describe("writeAuditLog", () => {
  it("derives owner and actor from the verified server context", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: "1ff5f552-038a-413b-94d7-6db1a87e45ea",
      error: null,
    });
    const context = {
      user: { sub: "937c8b0a-7c21-4604-a428-0a9523bbb3fc" },
      receiptId: "7738b1f3-760a-49b0-bb86-f7f9ed51784c",
      operationId: "60d74e72-8209-42df-ab94-eace52caf1b3",
      status: "Processing" as const,
      resultReference: null,
    };

    await writeAuditLog(
      context,
      {
        action: "Created",
        entityType: "Customer",
        changedFields: ["name"],
      },
      { rpc },
    );

    expect(rpc).toHaveBeenCalledWith(
      "write_audit_log",
      expect.objectContaining({
        p_verified_user_id: context.user.sub,
        p_operation_id: context.operationId,
      }),
    );
  });

  it("rejects a context without a UUID user subject before writing", async () => {
    const rpc = vi.fn();

    await expect(
      writeAuditLog(
        {
          user: { sub: "not-a-user-id" },
          operationId: crypto.randomUUID(),
        },
        { action: "Created", entityType: "Customer" },
        { rpc },
      ),
    ).rejects.toThrow("verifiedUserId");
    expect(rpc).not.toHaveBeenCalled();
  });
});
