// Hero score dial from sac-landing §2: a 270° gauge (75 of pathLength 100) with
// a brand-gradient value arc, ticks at both gauge ends and the apex, the big
// score, "of 100", and the tier dot + label. Rendered server-side at its final
// arc length (the original animated in via JS; the arc math is identical).
const TIERS = {
  relaxed: { label: "Relaxed", color: "var(--tier-relaxed)" },
  mild: { label: "Mild", color: "var(--tier-mild)" },
  moderate: { label: "Elevated", color: "var(--tier-moderate)" },
  high: { label: "High", color: "var(--tier-high)" },
  severe: { label: "Severe", color: "var(--tier-severe)" },
} as const;

export type ScoreTier = keyof typeof TIERS;

function tierFor(score: number): ScoreTier {
  if (score < 20) return "relaxed";
  if (score < 40) return "mild";
  if (score < 60) return "moderate";
  if (score < 80) return "high";
  return "severe";
}

export function ScoreDial({ score, tier }: { score: number; tier?: ScoreTier }) {
  const t = TIERS[tier ?? tierFor(score)];
  const arc = (Math.min(Math.max(score, 0), 100) / 100) * 75;

  return (
    <svg
      viewBox="0 0 260 244"
      role="img"
      aria-label={`Illustration of the daily stress score dial reading ${score}, tier ${t.label}`}
      className="block w-full max-w-[406px]"
    >
      <defs>
        <linearGradient id="sac-dial-grad" x1="0" y1="1" x2="1" y2="0">
          <stop offset="0%" stopColor="var(--grad-a)" />
          <stop offset="55%" stopColor="var(--accent)" />
          <stop offset="100%" stopColor="var(--grad-c)" />
        </linearGradient>
      </defs>
      <g transform="translate(0,4)">
        {/* Ticks at the gauge ends (135°, 45°) and its apex (270°). */}
        <g stroke="rgba(16,18,35,0.2)" strokeWidth="1.4">
          <line x1="59.3" y1="200.7" x2="50.1" y2="209.9" />
          <line x1="130" y1="30" x2="130" y2="17" />
          <line x1="200.7" y1="200.7" x2="209.9" y2="209.9" />
        </g>
        <circle
          cx="130" cy="130" r="100" fill="none"
          stroke="rgba(2,136,209,0.16)" strokeWidth="19"
          strokeLinecap="round" pathLength={100} strokeDasharray="75 25"
          transform="rotate(135 130 130)"
        />
        <circle
          cx="130" cy="130" r="100" fill="none"
          stroke="url(#sac-dial-grad)" strokeWidth="19"
          strokeLinecap="round" pathLength={100} strokeDasharray={`${arc} 100`}
          transform="rotate(135 130 130)"
        />
        <text x="130" y="128" textAnchor="middle" fill="var(--ink)" fontFamily="var(--font-roboto), sans-serif" fontSize={70} fontWeight={600} letterSpacing="-0.04em">
          {score}
        </text>
        <text x="130" y="150" textAnchor="middle" fill="var(--ink-muted)" fontFamily="var(--font-mono), monospace" fontSize={14}>
          of 100
        </text>
        <circle cx="105" cy="176" r="5" fill={t.color} />
        <text x="117" y="181" fill="var(--ink)" fontFamily="var(--font-roboto), sans-serif" fontSize={15.5} fontWeight={640}>
          {t.label}
        </text>
      </g>
    </svg>
  );
}
