"use client";

import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import {
  millisecondsUntilThemeBoundary,
  resolveTheme,
  type ResolvedTheme,
  type ThemePreference,
} from "@/lib/theme/resolve-theme";

export const THEME_STORAGE_KEY = "csig-theme-preference";

export type ThemeContextValue = {
  preference: ThemePreference;
  resolvedTheme: ResolvedTheme;
  setPreference: (preference: ThemePreference) => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

function isThemePreference(value: string | null): value is ThemePreference {
  return value === "auto" || value === "day" || value === "night";
}

export function ThemeProvider({
  children,
  now = () => new Date(),
}: {
  children: ReactNode;
  now?: () => Date;
}) {
  const [preference, setPreferenceState] = useState<ThemePreference>(() => {
    if (typeof window === "undefined") return "auto";
    const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
    return isThemePreference(stored) ? stored : "auto";
  });
  const [currentTime, setCurrentTime] = useState(now);
  const resolvedTheme = resolveTheme(preference, currentTime.getHours());

  useEffect(() => {
    document.documentElement.dataset.theme = resolvedTheme;
  }, [resolvedTheme]);

  useEffect(() => {
    if (preference !== "auto") return;
    const timeout = window.setTimeout(() => setCurrentTime(now()), millisecondsUntilThemeBoundary(currentTime));
    return () => window.clearTimeout(timeout);
  }, [currentTime, now, preference]);

  useEffect(() => {
    const onStorage = (event: StorageEvent) => {
      if (event.key === THEME_STORAGE_KEY && isThemePreference(event.newValue)) {
        setPreferenceState(event.newValue);
        setCurrentTime(now());
      }
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, [now]);

  const value = useMemo<ThemeContextValue>(
    () => ({
      preference,
      resolvedTheme,
      setPreference(nextPreference) {
        window.localStorage.setItem(THEME_STORAGE_KEY, nextPreference);
        setPreferenceState(nextPreference);
        setCurrentTime(now());
      },
    }),
    [now, preference, resolvedTheme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error("useTheme must be used within ThemeProvider");
  return value;
}
