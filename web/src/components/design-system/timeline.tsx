export type TimelineEntry = {
  id: string;
  time: string;
  type: string;
  title: string;
  context?: string;
  href?: string;
};

export function Timeline({ entries, label = "Memory Timeline" }: { entries: TimelineEntry[]; label?: string }) {
  return (
    <ol aria-label={label} className="m-0 list-none p-0">
      {entries.map((entry) => (
        <li className="grid grid-cols-[72px_112px_1fr] gap-5 border-b border-border py-5 max-sm:grid-cols-[72px_1fr] max-sm:gap-x-4" key={entry.id}>
          <time className="type-metadata text-muted">{entry.time}</time>
          <span className="type-label text-accent max-sm:col-start-2">{entry.type}</span>
          <div className="max-sm:col-span-2 max-sm:mt-2">
            {entry.href ? <a className="type-body-md text-ink hover:text-accent" href={entry.href}>{entry.title}</a> : <p className="type-body-md m-0 text-ink">{entry.title}</p>}
            {entry.context ? <p className="type-body-sm mb-0 mt-1 text-muted">{entry.context}</p> : null}
          </div>
        </li>
      ))}
    </ol>
  );
}
