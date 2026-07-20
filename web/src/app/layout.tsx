import type { Metadata } from "next";
import Script from "next/script";
import "@fontsource-variable/inter";
import "@fontsource-variable/noto-serif-sc";
import "@fontsource-variable/source-serif-4";
import { ThemeProvider } from "@/components/theme/theme-provider";
import { WallpaperLayer } from "@/components/wallpaper/wallpaper-layer";
import "./globals.css";

const themeScript = `(() => {
  const key = "csig-theme-preference";
  const stored = localStorage.getItem(key);
  const preference = stored === "day" || stored === "night" || stored === "auto" ? stored : "auto";
  const hour = new Date().getHours();
  document.documentElement.dataset.theme = preference === "auto" ? (hour >= 6 && hour < 18 ? "day" : "night") : preference;
})();`;

export const metadata: Metadata = {
  title: "CSIG Sales OS",
  description: "A private AI-powered Solution Sales workspace.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" className="h-full antialiased" suppressHydrationWarning>
      <head>
        <Script id="csig-theme-bootstrap" strategy="beforeInteractive">{themeScript}</Script>
      </head>
      <body className="flex min-h-full flex-col">
        <ThemeProvider>
          <WallpaperLayer />
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
