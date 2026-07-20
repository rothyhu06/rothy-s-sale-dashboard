import type { Metadata } from "next";
import "@fontsource-variable/inter";
import "@fontsource-variable/noto-serif-sc";
import "@fontsource-variable/source-serif-4";
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
    <html lang="zh-CN" className="h-full antialiased">
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  );
}
