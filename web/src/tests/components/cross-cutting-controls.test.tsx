import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { Badge, Checkbox, CommandDialog, Skeleton } from "@/components/design-system";

describe("cross-cutting Design System controls", () => {
  it("labels checkbox state accessibly", () => {
    render(<Checkbox label="Include archived" />);
    fireEvent.click(screen.getByRole("checkbox", { name: "Include archived" }));
    expect(screen.getByRole("checkbox", { name: "Include archived" })).toBeChecked();
  });

  it("provides a labelled searchable command dialog", () => {
    const onQueryChange = vi.fn();
    render(
      <CommandDialog onOpenChange={() => undefined} onQueryChange={onQueryChange} open query="" title="Search workspace">
        <button type="button">Knowledge result</button>
      </CommandDialog>,
    );
    fireEvent.change(screen.getByRole("searchbox", { name: "Search workspace" }), { target: { value: "AI" } });
    expect(onQueryChange).toHaveBeenCalledWith("AI");
    expect(screen.getByRole("dialog", { name: "Search workspace" })).toBeVisible();
  });

  it("keeps badges textual and skeletons non-announcing", () => {
    render(<><Badge tone="accent">Verified</Badge><Skeleton aria-label="Loading entry" /></>);
    expect(screen.getByText("Verified")).toHaveAttribute("data-tone", "accent");
    expect(screen.getByLabelText("Loading entry")).toHaveAttribute("aria-hidden", "true");
  });
});
