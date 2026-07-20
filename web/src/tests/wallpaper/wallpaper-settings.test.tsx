import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { ThemeProvider } from "@/components/theme/theme-provider";
import { WallpaperSettingsPanel } from "@/components/wallpaper/wallpaper-settings";
import type { WallpaperRepository } from "@/lib/wallpaper/repository";
import type { ResolvedTheme } from "@/lib/theme/resolve-theme";
import type { WallpaperSettings } from "@/lib/wallpaper/validation";

class MemoryWallpaperRepository implements WallpaperRepository {
  image: Blob | null = null;
  settings: Record<ResolvedTheme, WallpaperSettings> = {
    day: { opacity: 0.18, blurPx: 24, brightnessPercent: 100 },
    night: { opacity: 0.18, blurPx: 24, brightnessPercent: 68 },
  };
  async getImage() { return this.image; }
  async setImage(image: Blob) { this.image = image; }
  async removeImage() { this.image = null; }
  getSettings(theme: ResolvedTheme) { return this.settings[theme]; }
  setSettings(theme: ResolvedTheme, value: WallpaperSettings) { this.settings[theme] = value; }
}

function renderPanel(repository: WallpaperRepository) {
  return render(
    <ThemeProvider now={() => new Date(2026, 6, 20, 9)}>
      <WallpaperSettingsPanel repository={repository} />
    </ThemeProvider>,
  );
}

describe("WallpaperSettingsPanel", () => {
  it("uploads and removes a supported image", async () => {
    const repository = new MemoryWallpaperRepository();
    const user = userEvent.setup();
    renderPanel(repository);
    const image = new File([new Uint8Array(16)], "desk.webp", { type: "image/webp" });
    await user.upload(screen.getByLabelText("Upload wallpaper"), image);
    expect(repository.image).toBe(image);
    expect(screen.getByRole("status")).toHaveTextContent("Wallpaper updated.");
    await user.click(screen.getByRole("button", { name: "Remove" }));
    expect(repository.image).toBeNull();
    expect(screen.getByRole("status")).toHaveTextContent("Wallpaper removed.");
  });

  it("preserves the current image when validation fails", async () => {
    const repository = new MemoryWallpaperRepository();
    repository.image = new Blob(["current"], { type: "image/png" });
    const current = repository.image;
    renderPanel(repository);
    fireEvent.change(screen.getByLabelText("Upload wallpaper"), {
      target: { files: [new File(["gif"], "animated.gif", { type: "image/gif" })] },
    });
    expect(repository.image).toBe(current);
    expect(screen.getByRole("status")).toHaveTextContent("Choose a JPEG, PNG, or WebP image.");
  });

  it("restores approved defaults", async () => {
    const repository = new MemoryWallpaperRepository();
    repository.settings.day = { opacity: 0.02, blurPx: 3, brightnessPercent: 95 };
    const user = userEvent.setup();
    renderPanel(repository);
    await user.click(screen.getByRole("button", { name: "Restore defaults" }));
    expect(repository.settings.day).toEqual({ opacity: 0.18, blurPx: 24, brightnessPercent: 100 });
  });
});
