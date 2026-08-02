import { describe, expect, it, vi } from "vitest";

const ownerId = "937c8b0a-7c21-4604-a428-0a9523bbb3fc";
const { createCommandContext } = vi.hoisted(() => ({ createCommandContext: vi.fn() }));
vi.mock("@/lib/commands/command-context", () => ({ createCommandContext }));

import { createTagActions } from "@/features/tags/actions";

describe("createTag", () => {
  it("normalizes the name and injects the verified owner into the database command", async () => {
    createCommandContext.mockResolvedValue({
      user: { sub: ownerId },
      commandType: "CreateTag",
      clientRequestId: "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f",
    });
    const rpc = vi.fn().mockResolvedValue({
      data: [{ id: "7738b1f3-760a-49b0-bb86-f7f9ed51784c", name: "  AI 教育  ", normalized_name: "ai 教育", version: 1 }],
      error: null,
    });
    const actions = createTagActions({ authClient: {} as never, serviceClient: { rpc } as never });

    await actions.createTag({ name: "  AI 教育  ", dataLevel: "Level2" }, "4bcaf4a9-a42a-48a8-a511-ebf2c03dd91f");

    expect(rpc).toHaveBeenCalledWith("create_tag", expect.objectContaining({
      p_verified_user_id: ownerId,
      p_name: "AI 教育",
      p_normalized_name: "ai 教育",
      p_data_level: "Level2",
    }));
    expect(rpc.mock.calls[0]?.[1]).not.toHaveProperty("owner_id");
  });
});
