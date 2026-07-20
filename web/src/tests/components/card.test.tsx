import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Card } from "@/components/design-system/card";

describe("Card", () => {
  it("uses semantic interactive elements", () => {
    const { rerender } = render(<Card href="/customers/1" variant="entity">Open customer</Card>);
    expect(screen.getByRole("link", { name: "Open customer" })).toHaveAttribute("data-variant", "entity");
    rerender(<Card onClick={() => undefined} variant="action">Prepare questions</Card>);
    expect(screen.getByRole("button", { name: "Prepare questions" })).toBeInTheDocument();
  });

  it("keeps static cards non-interactive", () => {
    render(<Card variant="empty">Nothing here yet</Card>);
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
  });
});
