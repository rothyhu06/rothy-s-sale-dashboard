import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type ButtonVariant = "primary" | "secondary" | "text" | "destructive";
export type ButtonSize = "standard" | "large";

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
};

const variantStyles: Record<ButtonVariant, string> = {
  primary: "border-ink bg-ink text-paper hover:opacity-90",
  secondary: "border-border bg-paper text-ink hover:border-ink",
  text: "border-transparent bg-transparent text-ink hover:text-accent",
  destructive: "border-danger bg-paper text-danger hover:border-ink",
};

const sizeStyles: Record<ButtonSize, string> = {
  standard: "min-h-9 px-4",
  large: "min-h-11 px-5",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    children,
    className,
    disabled,
    loading = false,
    size = "standard",
    type = "button",
    variant = "primary",
    ...props
  },
  ref,
) {
  return (
    <button
      {...props}
      aria-busy={loading || undefined}
      className={cn(
        "radius-control type-control inline-flex items-center justify-center gap-2 border transition-[border-color,background-color,color,opacity,transform] duration-[var(--motion-base)] ease-[var(--motion-easing)] disabled:cursor-not-allowed disabled:opacity-45",
        variantStyles[variant],
        sizeStyles[size],
        className,
      )}
      data-size={size}
      data-variant={variant}
      disabled={disabled || loading}
      ref={ref}
      type={type}
    >
      <span className={loading ? "opacity-65" : undefined}>{children}</span>
    </button>
  );
});
