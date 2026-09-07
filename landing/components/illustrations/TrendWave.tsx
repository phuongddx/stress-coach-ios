// Trend chart from sac-landing §8 ("See your patterns"): horizontal gridlines,
// accent line over a fading area fill, and per-point dots in tier colors once
// they stay legible (≤ 12 points, as in the original). The default series is
// the design's illustrative 7-day shape.
const DEFAULT_POINTS = [34, 41, 28, 52, 47, 38, 31];

const W = 620;
const H = 210;
const TOP = 14;
const BOT = 190;

function tierColorFor(v: number): string {
  if (v < 20) return "var(--tier-relaxed)";
  if (v < 40) return "var(--tier-mild)";
  if (v < 60) return "var(--tier-moderate)";
  if (v < 80) return "var(--tier-high)";
  return "var(--tier-severe)";
}

export function TrendWave({ points = DEFAULT_POINTS }: { points?: number[] }) {
  const n = points.length;
  const stepX = n > 1 ? W / (n - 1) : W;
  const pts = points.map((v, i) => [i * stepX, BOT - (v / 100) * (BOT - TOP)] as const);
  const d = pts.map((p, i) => `${i ? "L" : "M"}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(" ");
  const areaD = `${d} L${W} ${BOT} L0 ${BOT} Z`;
  const showDots = n > 0 && n <= 12;
  const avg = n > 0 ? Math.round(points.reduce((a, b) => a + b, 0) / n) : null;

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      role="img"
      aria-label={avg === null ? "Illustration of a daily stress score trend line" : `Illustration of a daily stress score trend line averaging ${avg} out of 100`}
      className="block h-auto w-full"
    >
      <defs>
        <linearGradient id="sac-area-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="var(--grad-a)" stopOpacity={0.34} />
          <stop offset="100%" stopColor="var(--grad-a)" stopOpacity={0} />
        </linearGradient>
      </defs>
      <g stroke="rgba(16,18,35,0.08)" strokeWidth="1">
        <line x1="0" y1="20" x2="620" y2="20" />
        <line x1="0" y1="65" x2="620" y2="65" />
        <line x1="0" y1="110" x2="620" y2="110" />
        <line x1="0" y1="155" x2="620" y2="155" />
        <line x1="0" y1="190" x2="620" y2="190" stroke="rgba(16,18,35,0.16)" />
      </g>
      {n > 0 && <path d={areaD} fill="url(#sac-area-grad)" />}
      {n > 0 && (
        <path d={d} fill="none" stroke="var(--accent)" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" />
      )}
      {showDots &&
        pts.map((p, i) => (
          <circle key={i} cx={p[0].toFixed(1)} cy={p[1].toFixed(1)} r="5" fill={tierColorFor(points[i])} stroke="#fff" strokeWidth="2" />
        ))}
    </svg>
  );
}
