import { Moon, Sun } from "lucide-react";
import { useTheme } from "../hooks/useTheme";
import { cx } from "../utils/format";

export function ThemeToggle({ className }: { className?: string }) {
  const { theme, toggle } = useTheme();
  const next = theme === "dark" ? "light" : "dark";
  return (
    <button type="button" onClick={toggle} aria-label={`Switch to ${next} mode`} title={`Switch to ${next} mode`}
      className={cx("rounded-xl p-2.5 text-slate-500 transition hover:bg-white/10 hover:text-slate-800", className)}>
      {theme === "dark" ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
    </button>
  );
}
