import {
  cloneElement,
  forwardRef,
  type InputHTMLAttributes,
  type ReactElement,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from "react";
import { cn } from "@/lib/cn";

type ControlAccessibilityProps = {
  id?: string;
  "aria-describedby"?: string;
  "aria-invalid"?: boolean;
};

export type InputFieldProps = {
  id: string;
  label: string;
  description?: string;
  error?: string;
  required?: boolean;
  children: ReactElement<ControlAccessibilityProps>;
};

export function InputField({ children, description, error, id, label, required }: InputFieldProps) {
  const helpId = description ? `${id}-description` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  const describedBy = [helpId, errorId].filter(Boolean).join(" ") || undefined;
  return (
    <div className="grid gap-2">
      <label className="type-control text-ink" htmlFor={id}>
        {label}{required ? <span aria-hidden className="ml-1 text-danger">*</span> : null}
      </label>
      {cloneElement(children, {
        id,
        "aria-describedby": describedBy,
        "aria-invalid": error ? true : undefined,
      })}
      {description ? <p className="type-body-sm m-0 text-muted" id={helpId}>{description}</p> : null}
      {error ? <p className="type-body-sm m-0 text-danger" id={errorId}>{error}</p> : null}
    </div>
  );
}

const controlStyles = "radius-control type-control min-h-11 w-full border border-border bg-paper px-3 text-ink outline-none transition-colors placeholder:text-muted/70 hover:border-muted focus:border-accent disabled:cursor-not-allowed disabled:opacity-45 aria-invalid:border-danger";

export const TextInput = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(function TextInput({ className, ...props }, ref) {
  return <input {...props} className={cn(controlStyles, className)} ref={ref} />;
});

export const TextArea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(function TextArea({ className, ...props }, ref) {
  return <textarea {...props} className={cn(controlStyles, "min-h-28 resize-y py-3", className)} ref={ref} />;
});

export const SelectInput = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(function SelectInput({ className, ...props }, ref) {
  return <select {...props} className={cn(controlStyles, className)} ref={ref} />;
});
