import type { HTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/cn";

export type CardVariant = "action" | "entity" | "empty";
export type CardProps = Omit<HTMLAttributes<HTMLElement>, "onClick"> & {
  children: ReactNode;
  variant: CardVariant;
  href?: string;
  onClick?: () => void;
};

export function Card({ children, className, href, onClick, variant, ...props }: CardProps) {
  const styles = cn(
    "radius-card block w-full border border-border bg-paper p-6 text-left text-ink transition-[border-color,transform] duration-[var(--motion-base)] ease-[var(--motion-easing)]",
    (href || onClick) && "hover:-translate-y-px hover:border-muted",
    className,
  );
  if (href) return <a {...props} className={styles} data-variant={variant} href={href}>{children}</a>;
  if (onClick) return <button {...props} className={styles} data-variant={variant} onClick={onClick} type="button">{children}</button>;
  return <article {...props} className={styles} data-variant={variant}>{children}</article>;
}
