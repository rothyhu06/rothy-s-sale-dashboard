import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it } from "vitest";
import { ThemeProvider, useTheme } from "@/components/theme/theme-provider";
import { ThemeToggle } from "@/components/theme/theme-toggle";

function ThemeProbe() {
  const theme = useTheme();
  return <output>{`${theme.preference}:${theme.resolvedTheme}`}</output>;
}

describe("ThemeProvider", () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.removeAttribute("data-theme");
  });

  it("defaults to auto and resolves from local time", () => {
    render(
      <ThemeProvider now={() => new Date(2026, 6, 20, 9)}>
        <ThemeProbe />
      </ThemeProvider>,
    );
    expect(screen.getByText("auto:day")).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute("data-theme", "day");
  });

  it("persists a manual theme and exposes pressed state", async () => {
    const user = userEvent.setup();
    render(
      <ThemeProvider now={() => new Date(2026, 6, 20, 9)}>
        <ThemeToggle />
        <ThemeProbe />
      </ThemeProvider>,
    );
    await user.click(screen.getByRole("button", { name: "Night" }));
    expect(screen.getByText("night:night")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Night" })).toHaveAttribute("aria-pressed", "true");
    expect(localStorage.getItem("csig-theme-preference")).toBe("night");
  });

  it("reacts to preference changes from another tab", () => {
    render(
      <ThemeProvider now={() => new Date(2026, 6, 20, 9)}>
        <ThemeProbe />
      </ThemeProvider>,
    );
    act(() => {
      window.dispatchEvent(
        new StorageEvent("storage", {
          key: "csig-theme-preference",
          newValue: "night",
        }),
      );
    });
    expect(screen.getByText("night:night")).toBeInTheDocument();
  });
});
