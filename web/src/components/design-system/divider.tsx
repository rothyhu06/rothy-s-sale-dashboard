import { cn } from "@/lib/cn";

export type DividerVariant = "section" | "row" | "vertical" | "empty";

export function Divider({ className, variant = "section" }: { className?: string; variant?: DividerVariant }) {
  return (
    <hr
      aria-orientation={variant === "vertical" ? "vertical" : "horizontal"}
      className={cn(
        "m-0 border-0 border-border",
        variant === "section" && "w-full border-t",
        variant === "row" && "ml-8 w-[calc(100%-2rem)] border-t",
        variant === "vertical" && "h-full min-h-8 w-px border-l",
        variant === "empty" && "w-full border-t border-dashed",
        className,
      )}
      data-variant={variant}
    />
  );
}
