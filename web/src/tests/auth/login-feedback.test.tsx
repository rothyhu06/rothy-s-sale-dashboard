import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { LoginFeedback } from "@/app/(public)/login/login-feedback";

describe("LoginFeedback", () => {
  it.each([
    ["missing_credentials", "请输入邮箱和密码。"],
    ["invalid_credentials", "邮箱或密码不正确。"],
  ])("shows safe feedback for %s", (error, message) => {
    render(<LoginFeedback error={error} />);

    expect(screen.getByRole("alert")).toHaveTextContent(message);
  });

  it("does not render arbitrary query text", () => {
    render(<LoginFeedback error="<script>alert('unsafe')</script>" />);

    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.queryByText(/unsafe/)).not.toBeInTheDocument();
  });
});
