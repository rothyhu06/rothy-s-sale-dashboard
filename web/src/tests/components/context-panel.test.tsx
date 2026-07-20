import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ContextPanel } from "@/components/design-system/context-panel";

describe("ContextPanel", () => {
  it("provides quiet context without becoming a chat window", () => {
    render(<ContextPanel customer="Harbor University" opportunity="AI Teaching Assistant" capability="Customer Discovery" editorNote="Frame the business value before the architecture." actions={["Review discovery questions"]} />);
    expect(screen.getByRole("complementary", { name: "Today’s Context" })).toBeInTheDocument();
    expect(screen.getByText("Editor’s Note")).toBeInTheDocument();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
  });
});
