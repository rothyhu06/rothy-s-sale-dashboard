export type ThemePreference = "auto" | "day" | "night";
export type ResolvedTheme = "day" | "night";

export function resolveTheme(
  preference: ThemePreference,
  localHour: number,
): ResolvedTheme {
  if (!Number.isInteger(localHour) || localHour < 0 || localHour > 23) {
    throw new RangeError("localHour must be an integer from 0 through 23");
  }
  if (preference !== "auto") return preference;
  return localHour >= 6 && localHour < 18 ? "day" : "night";
}

export function millisecondsUntilThemeBoundary(now: Date): number {
  const next = new Date(now);
  if (now.getHours() < 6) {
    next.setHours(6, 0, 0, 0);
  } else if (now.getHours() < 18) {
    next.setHours(18, 0, 0, 0);
  } else {
    next.setDate(next.getDate() + 1);
    next.setHours(6, 0, 0, 0);
  }
  return next.getTime() - now.getTime();
}
