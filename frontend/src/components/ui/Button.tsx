import { Loader2 } from "lucide-react";
import { Link, type LinkProps } from "react-router-dom";
import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cx } from "../../utils/format";

export type Variant = "primary" | "secondary" | "outline" | "ghost" | "danger" | "success";
export type Size = "sm" | "md" | "lg";

const base =
  "inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition-all duration-150 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-2 focus-visible:ring-offset-base disabled:cursor-not-allowed disabled:opacity-60 active:scale-[.98] whitespace-nowrap";
const variants: Record<Variant, string> = {
  primary: "neon-btn text-brand-ink font-bold hover:brightness-110 hover:shadow-[0_0_32px_rgba(0,255,91,.55)]",
  secondary: "border border-slate-300 bg-brand-50 text-brand-600 hover:bg-brand-100",
  outline: "border border-slate-300 bg-white/[0.03] text-slate-800 hover:border-brand-500/60 hover:bg-brand-50 hover:text-brand-600",
  ghost: "text-slate-600 hover:bg-white/10",
  danger: "bg-rose-500 text-[#fff] hover:brightness-110 hover:shadow-[0_0_22px_rgba(244,63,94,.4)]",
  success: "border border-brand-500/60 bg-brand-100 text-brand-600 hover:bg-brand-200 hover:shadow-glow-sm",
};
const sizes: Record<Size, string> = { sm: "h-8 px-3 text-xs", md: "h-10 px-4 text-sm", lg: "h-12 px-6 text-base" };

export const buttonClasses = (variant: Variant = "primary", size: Size = "md", extra?: string) => cx(base, variants[variant], sizes[size], extra);

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> { variant?: Variant; size?: Size; loading?: boolean; icon?: ReactNode }

export function Button({ variant = "primary", size = "md", loading, icon, children, className, disabled, type = "button", ...rest }: Props) {
  return (
    <button type={type} className={cx(buttonClasses(variant, size), className)} disabled={disabled || loading} {...rest}>
      {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : icon}
      {children}
    </button>
  );
}

export function LinkButton({ variant = "primary", size = "md", className, children, ...rest }: LinkProps & { variant?: Variant; size?: Size }) {
  return <Link className={cx(buttonClasses(variant, size), className)} {...rest}>{children}</Link>;
}
