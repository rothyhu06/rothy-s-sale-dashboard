import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type SkeletonProps = HTMLAttributes<HTMLDivElement>;
export function Skeleton({ className, ...props }: SkeletonProps) {
  return <div {...props} aria-hidden="true" className={cn("radius-control h-4 w-full animate-pulse bg-border opacity-70 motion-reduce:animate-none", className)} />;
}
