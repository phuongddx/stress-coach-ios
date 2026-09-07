// Watch face illustration from sac-landing §9: abstract Apple Watch with band
// stubs, crown, a 270° score ring on the face, tier label, three complication
// micro-rings, and the TODAY caption. Static by default at the design's score.
const TIERS = {
  relaxed: { label: "Relaxed", color: "var(--tier-relaxed)" },
  mild: { label: "Mild", color: "var(--tier-mild)" },
  moderate: { label: "Elevated", color: "var(--tier-moderate)" },
  high: { label: "High", color: "var(--tier-high)" },
  severe: { label: "Severe", color: "var(--tier-severe)" },
} as const;

function tierFor(score: number): (typeof TIERS)[keyof typeof TIERS] {
  if (score < 20) return TIERS.relaxed;
  if (score < 40) return TIERS.mild;
  if (score < 60) return TIERS.moderate;
  if (score < 80) return TIERS.high;
  return TIERS.severe;
}

export function WatchGlyph({ score = 38 }: { score?: number }) {
  const t = tierFor(score);
  // Same math as the dial: the 270° gauge spans 75 of pathLength 100.
  const clamped = Math.min(Math.max(score, 0), 100);
  const arc = (clamped / 100) * 75;

  return (
    <svg
      viewBox="0 0 200 290"
      role="img"
      aria-label={`Illustration of the watch face showing a stress score of ${clamped} (${t.label}) and three complication rings`}
      className="block h-auto w-full max-w-[208px]"
    >
      <defs>
        <linearGradient id="sac-watch-ring" x1="0" y1="1" x2="1" y2="0">
          <stop offset="0%" stopColor="var(--grad-a)" />
          <stop offset="60%" stopColor="var(--accent)" />
          <stop offset="100%" stopColor="var(--grad-c)" />
        </linearGradient>
      </defs>
      {/* band */}
      <path d="M62 26 L60 6 h80 l-2 20" fill="rgba(255,255,255,0.14)" />
      <path d="M62 264 L60 284 h80 l-2 -20" fill="rgba(255,255,255,0.14)" />
      {/* case */}
      <rect x="34" y="26" width="132" height="238" rx="42" fill="rgba(255,255,255,0.10)" stroke="rgba(255,255,255,0.24)" strokeWidth="1.5" />
      <rect x="44" y="36" width="112" height="218" rx="34" fill="#0A0B16" />
      {/* crown */}
      <rect x="166" y="118" width="7" height="30" rx="3.5" fill="rgba(255,255,255,0.34)" />
      {/* score ring */}
      <circle cx="100" cy="122" r="42" fill="none" stroke="rgba(255,255,255,0.14)" strokeWidth="9" pathLength={100} strokeDasharray="75 25" strokeLinecap="round" transform="rotate(135 100 122)" />
      <circle cx="100" cy="122" r="42" fill="none" stroke="url(#sac-watch-ring)" strokeWidth="9" pathLength={100} strokeDasharray={`${arc} ${100 - arc}`} strokeLinecap="round" transform="rotate(135 100 122)" />
      <text x="100" y="118" textAnchor="middle" fill="#fff" fontFamily="var(--font-roboto), sans-serif" fontSize={34} fontWeight={600}>
        {clamped}
      </text>
      <text x="100" y="136" textAnchor="middle" fill="rgba(255,255,255,0.6)" fontFamily="var(--font-mono), monospace" fontSize={9} letterSpacing="0.1em">
        {t.label.toUpperCase()}
      </text>
      {/* complications */}
      <g>
        <circle cx="68" cy="196" r="13" fill="none" stroke="var(--accent-bright)" strokeWidth="3" pathLength={100} strokeDasharray="64 36" transform="rotate(135 68 196)" />
        <circle cx="100" cy="196" r="13" fill="none" stroke="var(--tier-relaxed)" strokeWidth="3" pathLength={100} strokeDasharray="40 60" transform="rotate(135 100 196)" />
        <circle cx="132" cy="196" r="13" fill="none" stroke="var(--tier-high)" strokeWidth="3" pathLength={100} strokeDasharray="72 28" transform="rotate(135 132 196)" />
        <circle cx="100" cy="226" r="4" fill="rgba(255,255,255,0.4)" />
      </g>
      <text x="100" y="70" textAnchor="middle" fill="rgba(255,255,255,0.5)" fontFamily="var(--font-mono), monospace" fontSize={9} letterSpacing="0.14em">
        TODAY
      </text>
    </svg>
  );
}
