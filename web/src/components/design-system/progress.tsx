export type ProgressProps = { label: string; level: string; value?: number };

export function Progress({ label, level, value }: ProgressProps) {
  const clamped = value === undefined ? undefined : Math.max(0, Math.min(100, value));
  return (
    <div className="grid gap-2">
      <div className="flex items-baseline justify-between gap-4">
        <span className="type-body-md text-ink">{label}</span>
        <span className="type-metadata text-muted">{level}</span>
      </div>
      {clamped === undefined ? null : (
        <div aria-label={label} aria-valuemax={100} aria-valuemin={0} aria-valuenow={clamped} className="h-0.5 overflow-hidden bg-border" role="progressbar">
          <div className="h-full bg-accent transition-[width] duration-[var(--motion-theme)] ease-[var(--motion-easing)]" style={{ width: `${clamped}%` }} />
        </div>
      )}
    </div>
  );
}
