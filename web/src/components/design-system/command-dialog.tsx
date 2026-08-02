"use client";

import type { ReactNode } from "react";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { TextInput } from "./input";

export type CommandDialogProps = { children: ReactNode; description?: string; empty?: ReactNode; onOpenChange: (open: boolean) => void; onQueryChange: (query: string) => void; open: boolean; query: string; title: string };
export function CommandDialog({ children, description, empty, onOpenChange, onQueryChange, open, query, title }: CommandDialogProps) {
  return (
    <Dialog onOpenChange={onOpenChange} open={open}>
      <DialogContent className="left-1/2 right-auto top-[12vh] bottom-auto w-[min(620px,calc(100vw-2.5rem))] -translate-x-1/2 p-0">
        <div className="border-b border-border p-6 pr-20">
          <DialogTitle className="type-heading-3">{title}</DialogTitle>
          {description ? <DialogDescription className="type-body-sm mb-0 mt-2 text-muted">{description}</DialogDescription> : null}
        </div>
        <div className="p-4">
          <TextInput aria-label={title} autoFocus onChange={(event) => onQueryChange(event.target.value)} placeholder="Search…" role="searchbox" value={query} />
          <div aria-label="Search results" className="mt-4 max-h-[50vh] overflow-y-auto" role="region">{children || empty}</div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
