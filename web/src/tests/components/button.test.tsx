import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { Button } from "@/components/design-system/button";

describe("Button", () => {
  it.each(["primary", "secondary", "text", "destructive"] as const)("renders the %s variant", (variant) => {
    render(<Button variant={variant}>Continue</Button>);
    expect(screen.getByRole("button", { name: "Continue" })).toHaveAttribute("data-variant", variant);
  });

  it("prevents activation and preserves its name while loading", async () => {
    const onClick = vi.fn();
    const user = userEvent.setup();
    render(<Button loading onClick={onClick}>Save note</Button>);
    const button = screen.getByRole("button", { name: "Save note" });
    expect(button).toHaveAttribute("aria-busy", "true");
    expect(button).toBeDisabled();
    await user.click(button);
    expect(onClick).not.toHaveBeenCalled();
  });

  it("supports the two approved sizes", () => {
    const { rerender } = render(<Button size="standard">Open</Button>);
    expect(screen.getByRole("button")).toHaveAttribute("data-size", "standard");
    rerender(<Button size="large">Open</Button>);
    expect(screen.getByRole("button")).toHaveAttribute("data-size", "large");
  });

  it("uses canvas foreground against the primary ink surface in every theme", () => {
    render(<Button>Continue</Button>);
    expect(screen.getByRole("button")).toHaveClass("!text-[var(--ds-color-canvas)]");
  });

  it("owns semantic foreground colors instead of inheriting from action containers", () => {
    const { rerender } = render(<Button variant="secondary">Search</Button>);
    expect(screen.getByRole("button")).toHaveClass("!text-[var(--ds-color-ink)]");
    rerender(<Button variant="destructive">Delete</Button>);
    expect(screen.getByRole("button")).toHaveClass("!text-[var(--ds-color-danger-ink)]");
  });
});
