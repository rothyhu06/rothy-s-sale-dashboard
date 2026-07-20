"use client";

import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useMemo,
  useState,
  useSyncExternalStore,
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
const THEME_CHANGE_EVENT = "csig-theme-preference-change";

function isThemePreference(value: string | null): value is ThemePreference {
  return value === "auto" || value === "day" || value === "night";
}

function getThemeSnapshot(): ThemePreference {
  const stored = window.localStorage.getItem(THEME_STORAGE_KEY);
  return isThemePreference(stored) ? stored : "auto";
}

function subscribeThemePreference(onStoreChange: () => void) {
  const onStorage = (event: StorageEvent) => {
    if (event.key === THEME_STORAGE_KEY) onStoreChange();
  };
  window.addEventListener("storage", onStorage);
  window.addEventListener(THEME_CHANGE_EVENT, onStoreChange);
  return () => {
    window.removeEventListener("storage", onStorage);
    window.removeEventListener(THEME_CHANGE_EVENT, onStoreChange);
  };
}

export function ThemeProvider({
  children,
  now = () => new Date(),
}: {
  children: ReactNode;
  now?: () => Date;
}) {
  const preference = useSyncExternalStore<ThemePreference>(subscribeThemePreference, getThemeSnapshot, () => "auto");
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

  const value = useMemo<ThemeContextValue>(
    () => ({
      preference,
      resolvedTheme,
      setPreference(nextPreference) {
        window.localStorage.setItem(THEME_STORAGE_KEY, nextPreference);
        setCurrentTime(now());
        window.dispatchEvent(new Event(THEME_CHANGE_EVENT));
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
