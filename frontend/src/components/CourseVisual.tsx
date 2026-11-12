import { cx } from "../utils/format";

const NEON = "#00FF5B";
const SOFT = "#3DFF83";
const FILL = "rgba(0,255,91,.16)";
const LINE = "rgba(255,255,255,.28)";

// One illustration per course category, drawn on a 400×240 canvas.
const Analytics = () => (
  <>
    {[[78, 150], [122, 118], [166, 132], [210, 92], [254, 72], [298, 48]].map(([x, y]) => (
      <rect key={x} x={x} y={y} width="28" height={190 - y} rx="5" fill={FILL} stroke={NEON} strokeOpacity=".55" />
    ))}
    <polyline points="92,132 136,100 180,114 224,74 268,54 312,30" fill="none" stroke={SOFT} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
    {[[92, 132], [136, 100], [180, 114], [224, 74], [268, 54], [312, 30]].map(([x, y]) => <circle key={x} cx={x} cy={y} r="5" fill="#04170d" stroke={SOFT} strokeWidth="2.5" />)}
    <line x1="60" y1="190" x2="344" y2="190" stroke={LINE} strokeWidth="2" strokeLinecap="round" />
  </>
);

const PaidAds = () => (
  <>
    {[78, 52, 26].map((r, i) => <circle key={r} cx="190" cy="112" r={r} fill={i === 2 ? FILL : "none"} stroke={NEON} strokeOpacity={0.35 + i * 0.25} strokeWidth="3" />)}
    <circle cx="190" cy="112" r="7" fill={NEON} />
    <path d="M214 136l74 28-30 11-11 30z" fill="#04170d" stroke={SOFT} strokeWidth="3" strokeLinejoin="round" />
  </>
);

const Social = () => {
  const nodes = [[92, 62], [100, 168], [200, 40], [300, 62], [312, 164], [204, 196]];
  return (
    <>
      {nodes.map(([x, y]) => <line key={x} x1="200" y1="118" x2={x} y2={y} stroke={NEON} strokeOpacity=".45" strokeWidth="2" />)}
      {nodes.map(([x, y]) => <circle key={x} cx={x} cy={y} r="15" fill="#06281c" stroke={SOFT} strokeWidth="2.5" />)}
      <circle cx="200" cy="118" r="38" fill={FILL} stroke={NEON} strokeWidth="3" />
      <path d="M200 136s-20-12-20-25a11 11 0 0 1 20-6 11 11 0 0 1 20 6c0 13-20 25-20 25z" fill={NEON} />
    </>
  );
};

const Seo = () => (
  <>
    {[66, 104, 142].map((y, i) => (
      <g key={y}>
        <rect x="220" y={y} width={118 - i * 22} height="10" rx="5" fill={i === 0 ? NEON : LINE} />
        <rect x="220" y={y + 15} width={82 - i * 12} height="6" rx="3" fill={LINE} fillOpacity=".55" />
      </g>
    ))}
    <circle cx="136" cy="102" r="58" fill={FILL} stroke={NEON} strokeWidth="6" />
    <line x1="178" y1="146" x2="218" y2="188" stroke={SOFT} strokeWidth="12" strokeLinecap="round" />
    <polyline points="104,122 126,100 142,112 170,80" fill="none" stroke={SOFT} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
  </>
);

const Content = () => (
  <>
    <rect x="118" y="30" width="150" height="180" rx="12" fill={FILL} stroke={NEON} strokeOpacity=".7" strokeWidth="3" />
    <rect x="138" y="54" width="80" height="11" rx="5.5" fill={NEON} />
    {[82, 104, 126, 148, 170].map((y, i) => <rect key={y} x="138" y={y} width={i % 2 ? 90 : 110} height="7" rx="3.5" fill={LINE} />)}
    <path d="M312 72l24 24-84 84-32 8 8-32z" fill="#04170d" stroke={SOFT} strokeWidth="3" strokeLinejoin="round" />
    <line x1="296" y1="88" x2="320" y2="112" stroke={SOFT} strokeWidth="3" />
  </>
);

const Growth = () => (
  <>
    <path d="M56 190l72-48 56 26 72-70 88-58v150z" fill={FILL} />
    <polyline points="56,190 128,142 184,168 256,98 344,40" fill="none" stroke={NEON} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M312 36l34 2-4 34" fill="none" stroke={NEON} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
  </>
);

function artFor(category: string) {
  const c = category.toLowerCase();
  if (/analytic|\bai\b|data/.test(c)) return <Analytics />;
  if (/paid|ppc|\bads?\b|advert/.test(c)) return <PaidAds />;
  if (/social/.test(c)) return <Social />;
  if (/seo|search/.test(c)) return <Seo />;
  if (/content|copy|writ/.test(c)) return <Content />;
  return <Growth />;
}

/** Large course visual: the uploaded thumbnail if there is one, otherwise an illustration for the category. Always dark, in both themes. */
export function CourseVisual({ category, src, alt = "", className }: { category: string; src?: string | null; alt?: string; className?: string }) {
  return (
    <div
      className={cx("relative isolate overflow-hidden rounded-xl", className)}
      style={{ background: "linear-gradient(135deg, #04170d 0%, #062b17 55%, #0a5a2c 100%)" }}
    >
      {src ? (
        <img src={src} alt={alt} width={1280} height={720} decoding="async" className="absolute inset-0 h-full w-full object-cover" />
      ) : (
        <>
          <div
            className="absolute inset-0"
            style={{
              backgroundImage: "linear-gradient(to right, rgba(255,255,255,.05) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,.05) 1px, transparent 1px)",
              backgroundSize: "32px 32px",
            }}
          />
          <div className="absolute -right-12 -top-12 h-44 w-44 rounded-full bg-[rgba(0,255,91,.28)] blur-3xl" />
          <svg viewBox="0 0 400 240" preserveAspectRatio="xMidYMid meet" className="absolute inset-0 h-full w-full" aria-hidden="true">{artFor(category)}</svg>
        </>
      )}
      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
      <span className="absolute bottom-3 left-3 max-w-[calc(100%-1.5rem)] truncate rounded-full border border-[rgba(0,255,91,.4)] bg-black/60 px-2.5 py-0.5 text-xs font-semibold text-[#00FF5B] backdrop-blur">{category}</span>
    </div>
  );
}
