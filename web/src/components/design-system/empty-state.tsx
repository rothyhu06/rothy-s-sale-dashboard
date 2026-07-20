import type { ReactNode } from "react";

export type EmptyStateProps = {
  title: string;
  description: string;
  action: ReactNode;
  link?: ReactNode;
};

export function EmptyState({ action, description, link, title }: EmptyStateProps) {
  return (
    <section className="radius-card flex min-h-56 flex-col items-start justify-center border border-dashed border-border bg-paper p-8">
      <h3 className="type-heading-3">{title}</h3>
      <p className="type-body-md mb-5 mt-2 max-w-lg text-muted">{description}</p>
      <div className="flex flex-wrap items-center gap-4">{action}{link}</div>
    </section>
  );
}
