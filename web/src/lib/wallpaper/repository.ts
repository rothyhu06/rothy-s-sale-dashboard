import type { ResolvedTheme } from "@/lib/theme/resolve-theme";
import type { WallpaperSettings } from "./validation";

export interface WallpaperRepository {
  getImage(): Promise<Blob | null>;
  setImage(image: Blob): Promise<void>;
  removeImage(): Promise<void>;
  getSettings(theme: ResolvedTheme): WallpaperSettings;
  setSettings(theme: ResolvedTheme, value: WallpaperSettings): void;
}
