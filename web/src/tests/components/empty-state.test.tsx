import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { EmptyState } from "@/components/design-system/empty-state";

describe("EmptyState", () => {
  it("invites one recommended action without treating zero data as an error", () => {
    render(<EmptyState action={<button type="button">Write the first note</button>} description="Your useful discoveries can begin here." title="A quiet library, for now" />);
    expect(screen.getByRole("heading", { name: "A quiet library, for now" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Write the first note" })).toBeInTheDocument();
  });
});
