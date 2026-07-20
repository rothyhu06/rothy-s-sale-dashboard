import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { FloatingAiEntry } from "@/components/design-system/floating-ai-entry";

describe("FloatingAiEntry", () => {
  it("opens the editor without gamified urgency", async () => {
    const onOpen = vi.fn();
    const user = userEvent.setup();
    render(<FloatingAiEntry onOpen={onOpen} />);
    const button = screen.getByRole("button", { name: "Ask Your Editor" });
    await user.click(button);
    expect(onOpen).toHaveBeenCalledOnce();
    expect(button.className).not.toMatch(/pulse|animate/);
  });
});
