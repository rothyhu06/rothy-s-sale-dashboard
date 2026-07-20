"use client";

import { useEffect, useState } from "react";
import { useTheme } from "@/components/theme/theme-provider";
import { browserWallpaperRepository } from "@/lib/wallpaper/indexed-db-repository";
import type { WallpaperRepository } from "@/lib/wallpaper/repository";
import { WALLPAPER_CHANGE_EVENT } from "./wallpaper-settings";

export function WallpaperLayer({ repository = browserWallpaperRepository }: { repository?: WallpaperRepository }) {
  const { resolvedTheme } = useTheme();
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const settings = repository.getSettings(resolvedTheme);

  useEffect(() => {
    let active = true;
    const applyImage = (image: Blob | null) => {
      if (!active) return;
      setImageUrl((current) => {
        if (current) URL.revokeObjectURL(current);
        return image ? URL.createObjectURL(image) : null;
      });
    };
    const refresh = () => void repository.getImage().then(applyImage).catch(() => applyImage(null));
    void repository.getImage().then(applyImage).catch(() => applyImage(null));
    window.addEventListener(WALLPAPER_CHANGE_EVENT, refresh);
    return () => {
      active = false;
      window.removeEventListener(WALLPAPER_CHANGE_EVENT, refresh);
    };
  }, [repository]);

  useEffect(() => () => {
    if (imageUrl) URL.revokeObjectURL(imageUrl);
  }, [imageUrl]);

  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
      {imageUrl ? (
        <div
          className="absolute -inset-8 bg-cover bg-center"
          style={{
            backgroundImage: `url(${imageUrl})`,
            filter: `blur(${settings.blurPx}px) brightness(${settings.brightnessPercent}%)`,
            opacity: settings.opacity,
          }}
        />
      ) : null}
      <div className="absolute inset-0 bg-[var(--wallpaper-overlay)]" />
    </div>
  );
}
