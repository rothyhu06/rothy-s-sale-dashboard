import type { Metadata } from "next";
import "@fontsource-variable/inter";
import "@fontsource-variable/noto-serif-sc";
import "@fontsource-variable/source-serif-4";
import { ThemeProvider } from "@/components/theme/theme-provider";
import { ThemeScript } from "@/components/theme/theme-script";
import { WallpaperLayer } from "@/components/wallpaper/wallpaper-layer";
import "./globals.css";

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
        <ThemeScript />
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
