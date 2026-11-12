import plugin from "tailwindcss/plugin";

// Theme colour backed by a CSS variable; color-mix keeps Tailwind opacity modifiers (bg-brand-500/20) working.
const c = (name) => `color-mix(in srgb, var(--c-${name}) calc(<alpha-value> * 100%), transparent)`;

/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: { sans: ["Outfit", "ui-sans-serif", "system-ui", "sans-serif"], display: ["Outfit", "Inter", "ui-sans-serif", "system-ui", "sans-serif"] },
      colors: {
        // Every colour resolves to a CSS variable (see src/index.css) so the UI can switch between dark and light themes.
        // Surfaces
        base: c("base"),
        panel: c("panel"),
        surface: c("surface"),
        field: c("field"),
        sunken: c("sunken"),
        // Foreground ink: white on the dark theme, deep green-black on the light theme
        white: c("white"),
        // Bright fills (buttons, avatars, active chips) — always paired with text-brand-ink
        neon: { DEFAULT: c("neon"), bright: c("neon-bright"), dark: c("neon-dark") },
        // Brand accents for text, icons, borders and tints
        brand: { 50: c("brand-50"), 100: c("brand-100"), 200: c("brand-200"), 300: c("brand-300"), 400: c("brand-400"), 500: c("brand-500"), 600: c("brand-600"), 700: c("brand-700"), 800: c("brand-800"), 900: c("brand-900"), ink: c("brand-ink") },
        // Neutral scale: low numbers = surfaces/borders, high numbers = text
        slate: { 50: c("slate-50"), 100: c("slate-100"), 200: c("slate-200"), 300: c("slate-300"), 400: c("slate-400"), 500: c("slate-500"), 600: c("slate-600"), 700: c("slate-700"), 800: c("slate-800"), 900: c("slate-900") },
        emerald: { 50: c("emerald-50"), 100: c("emerald-100"), 200: c("emerald-200"), 300: c("emerald-300"), 400: c("emerald-400"), 500: c("emerald-500"), 600: c("emerald-600"), 700: c("emerald-700"), 800: c("emerald-800") },
        amber: { 50: c("amber-50"), 100: c("amber-100"), 200: c("amber-200"), 400: c("amber-400"), 500: c("amber-500"), 600: c("amber-600"), 700: c("amber-700"), 800: c("amber-800") },
        rose: { 50: c("rose-50"), 100: c("rose-100"), 200: c("rose-200"), 300: c("rose-300"), 400: c("rose-400"), 500: c("rose-500"), 600: c("rose-600"), 700: c("rose-700"), 800: c("rose-800") },
        sky: { 50: c("sky-50"), 100: c("sky-100"), 500: c("sky-500"), 600: c("sky-600"), 700: c("sky-700") },
      },
      boxShadow: {
        card: "var(--shadow-card)",
        glow: "0 0 0 1px rgba(0,255,91,.4), 0 8px 28px -6px rgba(0,255,91,.16)",
        "glow-sm": "0 0 12px rgba(0,255,91,.35)",
      },
      keyframes: {
        fadeUp: { "0%": { opacity: 0, transform: "translateY(8px)" }, "100%": { opacity: 1, transform: "none" } },
        pop: { "0%": { opacity: 0, transform: "scale(.96)" }, "100%": { opacity: 1, transform: "none" } },
        slideIn: { "0%": { transform: "translateX(100%)" }, "100%": { transform: "none" } },
        slideInLeft: { "0%": { transform: "translateX(-100%)" }, "100%": { transform: "none" } },
        pulseGlow: { "0%,100%": { opacity: 0.55 }, "50%": { opacity: 1 } },
      },
      animation: {
        fadeUp: "fadeUp .35s ease-out both", pop: "pop .18s ease-out both",
        slideIn: "slideIn .25s ease-out both", slideInLeft: "slideInLeft .25s ease-out both",
        pulseGlow: "pulseGlow 2.4s ease-in-out infinite",
      },
    },
  },
  plugins: [
    // `light:` variant, e.g. `light:hidden`, for the few places that need different markup per theme
    plugin(({ addVariant }) => addVariant("light", ':root[data-theme="light"] &')),
  ],
};
