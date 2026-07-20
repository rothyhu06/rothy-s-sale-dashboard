import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { InputField, SelectInput, TextArea, TextInput } from "@/components/design-system/input";

describe("InputField", () => {
  it("keeps a visible label and associates help text", () => {
    render(
      <InputField description="Use a short working title." id="title" label="Title">
        <TextInput placeholder="Customer discovery" />
      </InputField>,
    );
    const input = screen.getByRole("textbox", { name: "Title" });
    expect(input).toHaveAttribute("id", "title");
    expect(input).toHaveAccessibleDescription("Use a short working title.");
  });

  it("announces errors without relying on color", () => {
    render(
      <InputField error="A customer is required." id="customer" label="Customer">
        <SelectInput><option value="">Choose one</option></SelectInput>
      </InputField>,
    );
    expect(screen.getByRole("combobox", { name: "Customer" })).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByText("A customer is required.")).toBeInTheDocument();
  });

  it("supports long-form writing", () => {
    render(<InputField id="reflection" label="Reflection"><TextArea /></InputField>);
    expect(screen.getByRole("textbox", { name: "Reflection" }).tagName).toBe("TEXTAREA");
  });
});
