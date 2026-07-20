import type { Metadata } from "next";
import { DesignSystemGallery } from "@/components/gallery/design-system-gallery";

export const metadata: Metadata = {
  title: "Design System | CSIG Sales OS",
  robots: { index: false, follow: false },
};

export default function DesignSystemPage() {
  return <DesignSystemGallery />;
}
