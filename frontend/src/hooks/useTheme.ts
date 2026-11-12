import { useSyncExternalStore } from "react";

export type Theme = "dark" | "light";

const KEY = "theme";
const META_COLOR: Record<Theme, string> = { dark: "#050505", light: "#FFFFFF" };
const listeners = new Set<() => void>();

/** Current theme, read from <html data-theme>. index.html applies the saved choice before first paint; dark is the default. */
const read = (): Theme => (document.documentElement.dataset.theme === "light" ? "light" : "dark");

export function setTheme(t: Theme) {
  document.documentElement.dataset.theme = t;
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", META_COLOR[t]);
  try { localStorage.setItem(KEY, t); } catch { /* storage unavailable (private mode) — theme still applies for this visit */ }
  listeners.forEach((l) => l());
}

export function useTheme() {
  const theme = useSyncExternalStore((l) => { listeners.add(l); return () => listeners.delete(l); }, read);
  return { theme, setTheme, toggle: () => setTheme(theme === "dark" ? "light" : "dark") };
}
