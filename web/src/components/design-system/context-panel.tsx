"use client";

import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";

export type ContextPanelProps = {
  customer?: string;
  opportunity?: string;
  capability?: string;
  editorNote?: string;
  actions?: string[];
};

export function ContextPanel(props: ContextPanelProps) {
  return <ContextContent {...props} />;
}

export function ContextPanelSheet({ children = "Open context", ...props }: ContextPanelProps & { children?: React.ReactNode }) {
  return (
    <Dialog>
      <DialogTrigger asChild><button className="type-control min-h-11 text-accent" type="button">{children}</button></DialogTrigger>
      <DialogContent>
        <DialogTitle className="type-heading-3">Today’s Context</DialogTitle>
        <DialogDescription className="sr-only">Current customer, opportunity, capability and editor note.</DialogDescription>
        <ContextContent {...props} labelled={false} />
      </DialogContent>
    </Dialog>
  );
}

function ContextContent({ actions = [], capability, customer, editorNote, labelled = true, opportunity }: ContextPanelProps & { labelled?: boolean }) {
  const content = (
    <div className="space-y-7">
      {labelled ? <h2 className="type-heading-3" id="context-title">Today’s Context</h2> : null}
      <ContextValue label="Current Customer" value={customer} />
      <ContextValue label="Current Opportunity" value={opportunity} />
      <ContextValue label="Current Capability" value={capability} />
      {editorNote ? <section className="border-t border-border pt-5"><h3 className="type-label text-accent">Editor’s Note</h3><p className="type-body-md mb-0 mt-2 text-ink">{editorNote}</p></section> : null}
      {actions.length ? <section className="border-t border-border pt-5"><h3 className="type-label text-muted">Suggested Actions</h3><ul className="type-body-sm mb-0 mt-2 space-y-2 pl-4 text-ink">{actions.map((action) => <li key={action}>{action}</li>)}</ul></section> : null}
    </div>
  );
  return labelled ? <aside aria-labelledby="context-title">{content}</aside> : content;
}

function ContextValue({ label, value }: { label: string; value?: string }) {
  if (!value) return null;
  return <div><p className="type-label m-0 text-muted">{label}</p><p className="type-body-md mb-0 mt-1 text-ink">{value}</p></div>;
}
