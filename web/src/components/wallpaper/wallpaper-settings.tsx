"use client";

import { type ChangeEvent, useState } from "react";
import { useTheme } from "@/components/theme/theme-provider";
import {
  browserWallpaperRepository,
  DEFAULT_WALLPAPER_SETTINGS,
} from "@/lib/wallpaper/indexed-db-repository";
import type { WallpaperRepository } from "@/lib/wallpaper/repository";
import { clampWallpaperSettings, validateWallpaperFile } from "@/lib/wallpaper/validation";

export const WALLPAPER_CHANGE_EVENT = "csig-wallpaper-change";

export function WallpaperSettingsPanel({
  repository = browserWallpaperRepository,
}: {
  repository?: WallpaperRepository;
}) {
  const { resolvedTheme } = useTheme();
  const [settingsByTheme, setSettingsByTheme] = useState(() => ({
    day: repository.getSettings("day"),
    night: repository.getSettings("night"),
  }));
  const settings = settingsByTheme[resolvedTheme];
  const [message, setMessage] = useState("");

  const notify = () => window.dispatchEvent(new Event(WALLPAPER_CHANGE_EVENT));

  const saveSettings = (next: typeof settings) => {
    const clamped = clampWallpaperSettings(resolvedTheme, next);
    repository.setSettings(resolvedTheme, clamped);
    setSettingsByTheme((current) => ({ ...current, [resolvedTheme]: clamped }));
    notify();
  };

  const onUpload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const validation = validateWallpaperFile(file);
    if (!validation.ok) {
      setMessage(validation.message);
      return;
    }
    try {
      await repository.setImage(file);
      setMessage("Wallpaper updated.");
      notify();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Wallpaper could not be updated.");
    } finally {
      event.target.value = "";
    }
  };

  const remove = async () => {
    try {
      await repository.removeImage();
      setMessage("Wallpaper removed.");
      notify();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Wallpaper could not be removed.");
    }
  };

  return (
    <section aria-labelledby="wallpaper-settings-title" className="space-y-6">
      <div>
        <h3 className="type-heading-3" id="wallpaper-settings-title">Wallpaper atmosphere</h3>
        <p className="type-body-sm mt-2 text-muted">Keep the image quiet enough that work remains the foreground.</p>
      </div>
      <div className="flex flex-wrap gap-3">
        <label className="type-control inline-flex min-h-11 cursor-pointer items-center rounded-[var(--radius-control)] border border-border bg-paper px-4">
          Upload or replace
          <input accept="image/jpeg,image/png,image/webp" aria-label="Upload wallpaper" className="sr-only" onChange={onUpload} type="file" />
        </label>
        <button className="type-control min-h-11 rounded-[var(--radius-control)] border border-border px-4" onClick={remove} type="button">Remove</button>
      </div>
      <div className="grid gap-4">
        <RangeControl label="Visibility" max={25} min={0} onChange={(value) => saveSettings({ ...settings, opacity: value / 100 })} value={Math.round(settings.opacity * 100)} />
        <RangeControl label="Blur" max={30} min={0} onChange={(value) => saveSettings({ ...settings, blurPx: value })} value={settings.blurPx} />
        <RangeControl label="Brightness" max={resolvedTheme === "day" ? 110 : 80} min={resolvedTheme === "day" ? 95 : 55} onChange={(value) => saveSettings({ ...settings, brightnessPercent: value })} value={settings.brightnessPercent} />
      </div>
      <button className="type-control text-accent underline-offset-4 hover:underline" onClick={() => saveSettings(DEFAULT_WALLPAPER_SETTINGS[resolvedTheme])} type="button">Restore defaults</button>
      <p aria-live="polite" className="type-body-sm min-h-5 text-muted" role="status">{message}</p>
    </section>
  );
}

function RangeControl({ label, max, min, onChange, value }: { label: string; max: number; min: number; onChange: (value: number) => void; value: number }) {
  return (
    <label className="grid grid-cols-[100px_1fr_48px] items-center gap-3">
      <span className="type-control">{label}</span>
      <input max={max} min={min} onChange={(event) => onChange(Number(event.target.value))} type="range" value={value} />
      <span className="type-metadata text-right text-muted">{value}</span>
    </label>
  );
}
