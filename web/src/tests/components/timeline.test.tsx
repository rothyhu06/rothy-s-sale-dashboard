import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Timeline } from "@/components/design-system/timeline";

describe("Timeline", () => {
  it("renders an ordered archive with optional source links", () => {
    render(<Timeline entries={[
      { id: "1", time: "09:00", type: "Learning", title: "Tencent Cloud AI Agent knowledge" },
      { id: "2", time: "11:00", type: "Interaction", title: "University information center discussion", href: "/interactions/2" },
    ]} />);
    expect(screen.getByRole("list").tagName).toBe("OL");
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
    expect(screen.getByRole("link", { name: "University information center discussion" })).toHaveAttribute("href", "/interactions/2");
  });
});
