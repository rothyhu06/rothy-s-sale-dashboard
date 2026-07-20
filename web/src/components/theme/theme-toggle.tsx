"use client";

import type { ThemePreference } from "@/lib/theme/resolve-theme";
import { useTheme } from "./theme-provider";

const options: Array<{ value: ThemePreference; label: string }> = [
  { value: "auto", label: "Auto" },
  { value: "day", label: "Day" },
  { value: "night", label: "Night" },
];

export function ThemeToggle() {
  const { preference, setPreference } = useTheme();
  return (
    <div aria-label="Theme" className="inline-flex rounded-[var(--radius-control)] border border-border bg-paper p-1" role="group">
      {options.map((option) => (
        <button
          aria-pressed={preference === option.value}
          className="type-control min-h-9 rounded-[var(--radius-control)] px-3 text-muted transition-colors aria-pressed:bg-ink aria-pressed:text-paper"
          key={option.value}
          onClick={() => setPreference(option.value)}
          type="button"
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}
