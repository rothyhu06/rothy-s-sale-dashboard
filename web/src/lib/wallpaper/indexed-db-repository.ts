import type { ResolvedTheme } from "@/lib/theme/resolve-theme";
import type { WallpaperRepository } from "./repository";
import { clampWallpaperSettings, type WallpaperSettings } from "./validation";

const DB_NAME = "csig-sales-os";
const STORE_NAME = "preferences";
const IMAGE_KEY = "wallpaper-image";

export const DEFAULT_WALLPAPER_SETTINGS: Record<ResolvedTheme, WallpaperSettings> = {
  day: { opacity: 0.18, blurPx: 24, brightnessPercent: 100 },
  night: { opacity: 0.18, blurPx: 24, brightnessPercent: 68 },
};

function settingsKey(theme: ResolvedTheme) {
  return `csig-wallpaper-settings-${theme}`;
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (!("indexedDB" in window)) {
      reject(new Error("Wallpaper storage is not available in this browser."));
      return;
    }
    const request = window.indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE_NAME)) {
        request.result.createObjectStore(STORE_NAME);
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new Error("Wallpaper storage could not be opened."));
  });
}

async function runTransaction<T>(
  mode: IDBTransactionMode,
  operation: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  const database = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, mode);
    const request = operation(transaction.objectStore(STORE_NAME));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new Error("Wallpaper storage operation failed."));
    transaction.oncomplete = () => database.close();
  });
}

export class IndexedDbWallpaperRepository implements WallpaperRepository {
  async getImage() {
    return (await runTransaction("readonly", (store) => store.get(IMAGE_KEY))) as Blob | null;
  }

  async setImage(image: Blob) {
    await runTransaction("readwrite", (store) => store.put(image, IMAGE_KEY));
  }

  async removeImage() {
    await runTransaction("readwrite", (store) => store.delete(IMAGE_KEY));
  }

  getSettings(theme: ResolvedTheme) {
    if (typeof window === "undefined") return DEFAULT_WALLPAPER_SETTINGS[theme];
    try {
      const stored = window.localStorage.getItem(settingsKey(theme));
      if (!stored) return DEFAULT_WALLPAPER_SETTINGS[theme];
      return clampWallpaperSettings(theme, JSON.parse(stored) as WallpaperSettings);
    } catch {
      return DEFAULT_WALLPAPER_SETTINGS[theme];
    }
  }

  setSettings(theme: ResolvedTheme, value: WallpaperSettings) {
    window.localStorage.setItem(settingsKey(theme), JSON.stringify(clampWallpaperSettings(theme, value)));
  }
}

export const browserWallpaperRepository = new IndexedDbWallpaperRepository();
