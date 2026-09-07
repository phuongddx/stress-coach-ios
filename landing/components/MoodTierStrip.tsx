// The five stress tiers as a strip of chips, in the design's tier palette
// (sac-landing legend/chip language). "Elevated" is the app's label for the
// 40–59 band, which the design page called "Moderate".
const TIERS = [
  { label: "Relaxed", color: "var(--tier-relaxed)" },
  { label: "Mild", color: "var(--tier-mild)" },
  { label: "Elevated", color: "var(--tier-moderate)" },
  { label: "High", color: "var(--tier-high)" },
  { label: "Severe", color: "var(--tier-severe)" },
] as const;

export function MoodTierStrip() {
  return (
    <ul role="list" className="flex flex-wrap items-center gap-2.5">
      {TIERS.map((t) => (
        <li
          key={t.label}
          className="flex items-center gap-2 rounded-full border border-ink/10 bg-white px-3.5 py-1.5 text-[0.8125rem] font-semibold text-ink"
        >
          <span aria-hidden="true" className="size-2.5 rounded-full" style={{ background: t.color }} />
          {t.label}
        </li>
      ))}
    </ul>
  );
}
