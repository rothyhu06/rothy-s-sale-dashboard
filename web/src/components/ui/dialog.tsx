"use client";

import * as React from "react";
import { Dialog as DialogPrimitive } from "radix-ui";
import { cn } from "@/lib/cn";

export const Dialog = DialogPrimitive.Root;
export const DialogTrigger = DialogPrimitive.Trigger;
export const DialogClose = DialogPrimitive.Close;
export const DialogTitle = DialogPrimitive.Title;
export const DialogDescription = DialogPrimitive.Description;

export function DialogContent({ children, className, ...props }: React.ComponentProps<typeof DialogPrimitive.Content>) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className="fixed inset-0 z-40 bg-canvas/85" />
      <DialogPrimitive.Content
        {...props}
        className={cn("radius-floating fixed bottom-5 right-5 z-50 max-h-[calc(100vh-2.5rem)] w-[min(420px,calc(100vw-2.5rem))] overflow-auto border border-border bg-paper p-6 text-ink outline-none", className)}
      >
        {children}
        <DialogPrimitive.Close className="type-control absolute right-4 top-4 min-h-11 min-w-11 text-muted" aria-label="Close">Close</DialogPrimitive.Close>
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}
