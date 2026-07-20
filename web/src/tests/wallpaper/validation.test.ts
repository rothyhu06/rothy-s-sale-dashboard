import { describe, expect, it } from "vitest";
import {
  clampWallpaperSettings,
  validateWallpaperFile,
} from "@/lib/wallpaper/validation";

function file(type: string, size = 16) {
  return new File([new Uint8Array(size)], "wallpaper", { type });
}

describe("validateWallpaperFile", () => {
  it.each(["image/jpeg", "image/png", "image/webp"])("accepts %s", (type) => {
    expect(validateWallpaperFile(file(type))).toEqual({ ok: true });
  });

  it("rejects unsupported files without replacing the current image", () => {
    expect(validateWallpaperFile(file("image/gif"))).toEqual({
      ok: false,
      message: "Choose a JPEG, PNG, or WebP image.",
    });
  });

  it("rejects empty and oversized files", () => {
    expect(validateWallpaperFile(file("image/png", 0)).ok).toBe(false);
    expect(validateWallpaperFile(file("image/png", 8 * 1024 * 1024 + 1))).toEqual({
      ok: false,
      message: "Choose an image smaller than 8 MB.",
    });
  });
});

describe("clampWallpaperSettings", () => {
  it("clamps day values to the approved range", () => {
    expect(clampWallpaperSettings("day", { opacity: 1, blurPx: -2, brightnessPercent: 80 })).toEqual({
      opacity: 0.25,
      blurPx: 0,
      brightnessPercent: 95,
    });
  });

  it("clamps night brightness separately", () => {
    expect(clampWallpaperSettings("night", { opacity: -1, blurPx: 50, brightnessPercent: 100 })).toEqual({
      opacity: 0,
      blurPx: 30,
      brightnessPercent: 80,
    });
  });
});
