import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Navigation } from "@/components/design-system/navigation";

const groups = [{ label: "Workspace", items: [{ label: "Home", href: "/", active: true }, { label: "Customers", href: "/customers" }] }];

describe("Navigation", () => {
  it("renders a personal studio index with semantic current state", () => {
    render(<Navigation groups={groups} profile={{ name: "Yuxing", detail: "Solution Sales" }} />);
    expect(screen.getByRole("navigation", { name: "Studio index" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Home" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByText("Workspace")).toBeInTheDocument();
    expect(screen.getByText("Solution Sales")).toBeInTheDocument();
  });
});
