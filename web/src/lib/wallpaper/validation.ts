import type { ResolvedTheme } from "@/lib/theme/resolve-theme";

export type WallpaperSettings = {
  opacity: number;
  blurPx: number;
  brightnessPercent: number;
};

export function validateWallpaperFile(file: File): { ok: true } | { ok: false; message: string } {
  if (!(["image/jpeg", "image/png", "image/webp"] as string[]).includes(file.type)) {
    return { ok: false, message: "Choose a JPEG, PNG, or WebP image." };
  }
  if (file.size === 0) return { ok: false, message: "Choose a non-empty image." };
  if (file.size > 8 * 1024 * 1024) {
    return { ok: false, message: "Choose an image smaller than 8 MB." };
  }
  return { ok: true };
}

export function clampWallpaperSettings(
  theme: ResolvedTheme,
  settings: WallpaperSettings,
): WallpaperSettings {
  const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));
  return {
    opacity: clamp(settings.opacity, 0, 0.25),
    blurPx: clamp(settings.blurPx, 0, 30),
    brightnessPercent: clamp(settings.brightnessPercent, theme === "day" ? 95 : 55, theme === "day" ? 110 : 80),
  };
}
