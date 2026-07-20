import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Progress } from "@/components/design-system/progress";

describe("Progress", () => {
  it("clamps numeric progress and keeps the meaning visible", () => {
    render(<Progress label="Cloud Knowledge" level="Foundation" value={120} />);
    const progress = screen.getByRole("progressbar", { name: "Cloud Knowledge" });
    expect(progress).toHaveAttribute("aria-valuenow", "100");
    expect(screen.getByText("Foundation")).toBeInTheDocument();
  });

  it("uses text for unknown progress", () => {
    render(<Progress label="Account Management" level="Not assessed" />);
    expect(screen.queryByRole("progressbar")).not.toBeInTheDocument();
    expect(screen.getByText("Not assessed")).toBeInTheDocument();
  });
});
