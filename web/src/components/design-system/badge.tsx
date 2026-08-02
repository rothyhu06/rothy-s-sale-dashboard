import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type BadgeTone = "neutral" | "accent" | "success" | "danger";
export type BadgeProps = HTMLAttributes<HTMLSpanElement> & { tone?: BadgeTone };
const tones: Record<BadgeTone, string> = { neutral: "border-border text-muted", accent: "border-accent text-accent", success: "border-success text-ink", danger: "border-danger text-danger" };

export function Badge({ className, tone = "neutral", ...props }: BadgeProps) {
  return <span {...props} className={cn("type-metadata radius-full inline-flex min-h-6 items-center border px-2.5", tones[tone], className)} data-tone={tone} />;
}
