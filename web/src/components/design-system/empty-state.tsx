import type { ReactNode } from "react";

export type EmptyStateProps = {
  title: string;
  description: string;
  action: ReactNode;
  link?: ReactNode;
  headingLevel?: 2 | 3;
};

export function EmptyState({ action, description, headingLevel = 2, link, title }: EmptyStateProps) {
  const Heading = headingLevel === 2 ? "h2" : "h3";
  return (
    <section className="radius-card flex min-h-56 flex-col items-start justify-center border border-dashed border-border bg-paper p-8">
      <Heading className="type-heading-3">{title}</Heading>
      <p className="type-body-md mb-5 mt-2 max-w-lg text-muted">{description}</p>
      <div className="flex flex-wrap items-center gap-4">{action}{link}</div>
    </section>
  );
}
