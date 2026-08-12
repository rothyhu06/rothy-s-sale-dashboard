import type { ReactNode } from "react";

export type SectionHeaderProps = {
  title: string;
  description?: string;
  metadata?: string;
  action?: ReactNode;
  level?: 1 | 2;
};

export function SectionHeader({ action, description, level = 2, metadata, title }: SectionHeaderProps) {
  const Heading = level === 1 ? "h1" : "h2";
  return (
    <header className="flex items-end justify-between gap-6 max-sm:items-start max-sm:flex-col max-sm:gap-3">
      <div className="max-w-2xl">
        <Heading className="type-heading-2">{title}</Heading>
        {description ? <p className="type-body-md mb-0 mt-2 text-muted">{description}</p> : null}
      </div>
      <div className="type-control flex shrink-0 items-center gap-4 text-accent">
        {metadata ? <span className="type-metadata text-muted">{metadata}</span> : null}
        {action}
      </div>
    </header>
  );
}
