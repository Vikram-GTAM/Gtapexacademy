import { forwardRef, useId, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes, type TextareaHTMLAttributes } from "react";
import { cx } from "../../utils/format";

const field =
  "block w-full rounded-xl border bg-field px-3.5 text-sm text-slate-900 placeholder:text-slate-400 transition focus:outline-none focus:ring-2 focus:ring-brand-500/25 disabled:bg-slate-50 disabled:text-slate-500";

function Wrapper({ id, label, error, hint, children }: { id: string; label?: string; error?: string; hint?: string; children: ReactNode }) {
  return (
    <div>
      {label && <label htmlFor={id} className="mb-1.5 block text-sm font-medium text-slate-700">{label}</label>}
      {children}
      {error ? <p className="mt-1.5 text-xs text-rose-600" role="alert">{error}</p> : hint ? <p className="mt-1.5 text-xs text-slate-500">{hint}</p> : null}
    </div>
  );
}

interface InputProps extends InputHTMLAttributes<HTMLInputElement> { label?: string; error?: string; hint?: string; icon?: ReactNode }
export const Input = forwardRef<HTMLInputElement, InputProps>(({ label, error, hint, icon, className, id, ...rest }, ref) => {
  const auto = useId();
  const fid = id ?? auto;
  return (
    <Wrapper id={fid} label={label} error={error} hint={hint}>
      <div className="relative">
        {icon && <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-slate-400">{icon}</span>}
        <input ref={ref} id={fid} aria-invalid={!!error} className={cx(field, "h-11", !!icon && "pl-10", error ? "border-rose-400" : "border-slate-300 focus:border-brand-500", className)} {...rest} />
      </div>
    </Wrapper>
  );
});
Input.displayName = "Input";

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> { label?: string; error?: string; hint?: string }
export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(({ label, error, hint, className, id, ...rest }, ref) => {
  const auto = useId();
  const fid = id ?? auto;
  return (
    <Wrapper id={fid} label={label} error={error} hint={hint}>
      <textarea ref={ref} id={fid} aria-invalid={!!error} className={cx(field, "min-h-[96px] py-2.5", error ? "border-rose-400" : "border-slate-300 focus:border-brand-500", className)} {...rest} />
    </Wrapper>
  );
});
Textarea.displayName = "Textarea";

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> { label?: string; error?: string; hint?: string }
export const Select = forwardRef<HTMLSelectElement, SelectProps>(({ label, error, hint, className, id, children, ...rest }, ref) => {
  const auto = useId();
  const fid = id ?? auto;
  return (
    <Wrapper id={fid} label={label} error={error} hint={hint}>
      <select ref={ref} id={fid} className={cx(field, "h-11 pr-8", error ? "border-rose-400" : "border-slate-300 focus:border-brand-500", className)} {...rest}>{children}</select>
    </Wrapper>
  );
});
Select.displayName = "Select";

export function Checkbox({ label, checked, onChange, hint }: { label: string; checked: boolean; onChange: (v: boolean) => void; hint?: string }) {
  const id = useId();
  return (
    <label htmlFor={id} className="flex cursor-pointer items-start gap-3">
      <input id={id} type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="mt-0.5 h-4 w-4 rounded border-slate-300 accent-brand-500 focus:ring-brand-500" />
      <span><span className="text-sm font-medium text-slate-700">{label}</span>{hint && <span className="block text-xs text-slate-500">{hint}</span>}</span>
    </label>
  );
}
