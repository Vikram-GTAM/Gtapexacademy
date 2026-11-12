import { TrendingUp } from "lucide-react";
import { Link } from "react-router-dom";
import { cx } from "../utils/format";

/** `compact` is for the sidebar, where the logo shares its row with the Admin label. */
export function Logo({ to = "/", className, compact = false }: { to?: string; className?: string; compact?: boolean }) {
  const height = compact ? "h-10" : "h-14";
  return (
    <Link to={to} className={cx("flex shrink-0 items-center", className)} aria-label="GTapex Academy home">
      <img src="/gtapex-academy-logo-dark.webp" alt="GTapex Academy" width={568} height={168} loading="lazy" decoding="async" className={cx(height, "w-auto light:hidden")} />
      {/* original-colour logo (green + black lettering) for the light theme */}
      <img src="/gtapex-academy-logo-light.webp" alt="GTapex Academy" width={600} height={168} loading="lazy" decoding="async" className={cx(height, "hidden w-auto light:block")} />
    </Link>
  );
}

const gradients = [
  ["#052e1a", "#00A83F"], ["#06281c", "#00E652"], ["#0a2a1a", "#3DFF83"], ["#0b3d20", "#00FF5B"], ["#062b17", "#00A83F"], ["#0f3320", "#3DFF83"],
];
// Generated thumbnails are always a dark green gradient, so their overlays use fixed bright greens in both themes.
export function CourseThumb({ title, src, className, category }: { title: string; src?: string | null; className?: string; category?: string }) {
  if (src) return <img src={src} alt={title} width={1280} height={720} loading="lazy" decoding="async" className={cx("object-cover", className)} />;
  let h = 0;
  for (const c of title) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const [a, b] = gradients[h % gradients.length];
  return (
    <div className={cx("relative flex items-end overflow-hidden p-4", className)} style={{ background: `linear-gradient(135deg, ${a}, ${b})` }} aria-hidden="true">
      <div className="absolute inset-0 grid-bg opacity-60" /><div className="absolute -right-6 -top-6 h-28 w-28 rounded-full bg-[rgba(0,255,91,.25)] blur-xl" />
      <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
      <TrendingUp className="absolute right-4 top-4 h-8 w-8 text-[rgba(0,255,91,.8)]" />
      {category && <span className="relative rounded-full border border-[rgba(0,255,91,.4)] bg-black/50 px-2.5 py-0.5 text-xs font-semibold text-[#00FF5B] backdrop-blur">{category}</span>}
    </div>
  );
}
