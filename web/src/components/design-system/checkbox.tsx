"use client";

import { forwardRef, useId, type InputHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type CheckboxProps = Omit<InputHTMLAttributes<HTMLInputElement>, "type"> & { label: string; description?: string };

export const Checkbox = forwardRef<HTMLInputElement, CheckboxProps>(function Checkbox({ className, description, id: providedId, label, ...props }, ref) {
  const generatedId = useId();
  const id = providedId ?? generatedId;
  const descriptionId = description ? `${id}-description` : undefined;
  return (
    <label className={cn("inline-grid cursor-pointer grid-cols-[20px_1fr] gap-x-3 gap-y-1 text-ink", className)} htmlFor={id}>
      <input {...props} aria-describedby={descriptionId} className="radius-control peer col-start-1 row-start-1 mt-0.5 size-5 appearance-none border border-border bg-paper transition-colors checked:border-ink checked:bg-ink disabled:cursor-not-allowed disabled:opacity-45" id={id} ref={ref} type="checkbox" />
      <span aria-hidden className="pointer-events-none col-start-1 row-start-1 mt-1 hidden text-center text-[10px] leading-4 text-paper peer-checked:block">✓</span>
      <span className="type-control col-start-2 row-start-1">{label}</span>
      {description ? <span className="type-body-sm col-start-2 row-start-2 text-muted" id={descriptionId}>{description}</span> : null}
    </label>
  );
});
