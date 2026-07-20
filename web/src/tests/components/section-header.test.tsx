import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Divider } from "@/components/design-system/divider";
import { SectionHeader } from "@/components/design-system/section-header";

describe("SectionHeader", () => {
  it("renders the editorial structure and one text action", () => {
    render(<SectionHeader action={<a href="#all">View all</a>} description="What deserves attention today." metadata="20 July" title="Today’s Work" />);
    expect(screen.getByRole("heading", { name: "Today’s Work" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "View all" })).toBeInTheDocument();
    expect(screen.getByText("20 July")).toBeInTheDocument();
  });
});

describe("Divider", () => {
  it.each(["section", "row", "vertical", "empty"] as const)("renders %s", (variant) => {
    render(<Divider variant={variant} />);
    expect(screen.getByRole("separator")).toHaveAttribute("data-variant", variant);
  });
});
