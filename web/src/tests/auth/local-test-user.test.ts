import { describe, expect, it, vi } from "vitest";
import { ensureDeterministicLocalUser } from "../../../e2e/support/local-test-user";

describe("ensureDeterministicLocalUser", () => {
  it("reuses an existing local test account and resets its password", async () => {
    const existing = { id: "937c8b0a-7c21-4604-a428-0a9523bbb3fc", email: "auth-e2e-owner@example.test" };
    const admin = {
      listUsers: vi.fn().mockResolvedValue({ data: { users: [existing] }, error: null }),
      updateUserById: vi.fn().mockResolvedValue({ data: { user: existing }, error: null }),
      createUser: vi.fn(),
    };

    await expect(
      ensureDeterministicLocalUser(admin, existing.email, "reset-password"),
    ).resolves.toEqual(existing);
    expect(admin.updateUserById).toHaveBeenCalledWith(existing.id, {
      password: "reset-password",
      email_confirm: true,
    });
    expect(admin.createUser).not.toHaveBeenCalled();
  });
});
