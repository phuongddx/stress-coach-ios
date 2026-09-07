// "Your stress, scored", ported from sac-landing §4: the five-signal factor
// grid, the animated five-tier visualisation, and the factor-breakdown card.
// The tier bars and breakdown fills animate on scroll via CSS view-timelines
// (no JS observer); without scroll-driven-animation support — or under
// prefers-reduced-motion — everything renders in its final state.
import type { CSSProperties } from "react";
import { SectionHeading } from "@/components/SectionHeading";

const SECTION_CSS = `
@supports (animation-timeline: view()){
  .sac-viz{view-timeline-name:--sac-scoreviz}
  .sac-tier-bar{animation:sac-bar-grow 1s cubic-bezier(.22,.68,.16,1) both;animation-timeline:--sac-scoreviz}
  .sac-tier:nth-child(1) .sac-tier-bar{animation-range:entry 0% entry 50%}
  .sac-tier:nth-child(2) .sac-tier-bar{animation-range:entry 8% entry 58%}
  .sac-tier:nth-child(3) .sac-tier-bar{animation-range:entry 16% entry 66%}
  .sac-tier:nth-child(4) .sac-tier-bar{animation-range:entry 24% entry 74%}
  .sac-tier:nth-child(5) .sac-tier-bar{animation-range:entry 32% entry 82%}
  .sac-bd-fill{animation:sac-fill-grow 1.1s cubic-bezier(.22,.68,.16,1) both;animation-timeline:--sac-scoreviz}
  .sac-bd-row:nth-child(1) .sac-bd-fill{animation-range:entry 5% entry 55%}
  .sac-bd-row:nth-child(2) .sac-bd-fill{animation-range:entry 13% entry 63%}
  .sac-bd-row:nth-child(3) .sac-bd-fill{animation-range:entry 21% entry 71%}
  .sac-bd-row:nth-child(4) .sac-bd-fill{animation-range:entry 29% entry 79%}
  .sac-bd-row:nth-child(5) .sac-bd-fill{animation-range:entry 37% entry 87%}
}
@keyframes sac-bar-grow{from{transform:scaleY(0)}to{transform:scaleY(1)}}
@keyframes sac-fill-grow{from{width:0}to{width:var(--w)}}
@media (prefers-reduced-motion: reduce){
  .sac-tier-bar{animation:none;transform:none}
  .sac-bd-fill{animation:none;width:var(--w)}
}
`;

// Stroke icon paths from the design's sprite.
const FACTOR_ICONS = {
  hrv: <><path d="M2 12h3.2l1.9-5.4 2.7 11L13 9.4l1.6 4.2h1.9" /><path d="M18.5 13.6h3.5" /></>,
  heart: <path d="M12 20.2s-7.6-4.5-7.6-9.9A4.3 4.3 0 0 1 12 7.4a4.3 4.3 0 0 1 7.6 2.9c0 5.4-7.6 9.9-7.6 9.9Z" />,
  sleep: <path d="M20.4 14.6A8.3 8.3 0 1 1 9.6 3.7a6.6 6.6 0 0 0 10.8 10.9Z" />,
  activity: <><circle cx="13.6" cy="4.5" r="1.8" /><path d="M8 21l2.2-5.4 3.4 2.1L15 21" /><path d="M5 11.4l3-2.8 3.3 1.4 2 3.1 3.4.8" /></>,
  recovery: <><path d="M12 3.2a8.8 8.8 0 1 0 8.8 8.8" /><path d="M20.8 3.6v5.2h-5.2" /><path d="M8.6 12.6l2.4 2.4 4.4-5" /></>,
} as const;

const FACTORS = [
  { id: "hrv", name: "Heart rate variability", copy: "The beat-to-beat variation that tracks how much load your body is under." },
  { id: "heart", name: "Heart rate", copy: "Resting and waking rates, read against your own baseline." },
  { id: "sleep", name: "Sleep", copy: "How much you got and how settled it was." },
  { id: "activity", name: "Activity", copy: "Movement through the day — too little and too much both register." },
  { id: "recovery", name: "Recovery", copy: "Whether you're bouncing back between demands, or stacking them." },
] as const;

// Mood faces from the design's sprite: eyes + a mouth curve per tier.
function MoodFace({ mouth }: { mouth: string }) {
  return (
    <svg viewBox="0 0 24 24" width="26" height="26" fill="none" aria-hidden="true">
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <circle cx="15" cy="10" r="1.5" fill="currentColor" />
      <path d={mouth} stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

const TIERS = [
  { name: "Relaxed", color: "var(--tier-relaxed)", height: 34, mouth: "M9 15s1.5 1.5 3 1.5 3-1.5 3-1.5" },
  { name: "Mild", color: "var(--tier-mild)", height: 50, mouth: "M9 15h6" },
  { name: "Elevated", color: "var(--tier-moderate)", height: 66, mouth: "M9 14h6" },
  { name: "High", color: "var(--tier-high)", height: 82, mouth: "M9 16c1.5-1.5 4.5-1.5 6 0" },
  { name: "Severe", color: "var(--tier-severe)", height: 98, mouth: "M8 17c2-2 6-2 8 0" },
] as const;

const BREAKDOWN = [
  { label: "HRV", value: 42 },
  { label: "Heart rate", value: 30 },
  { label: "Sleep", value: 55 },
  { label: "Activity", value: 22 },
  { label: "Recovery", value: 35 },
] as const;

const GRADIENT = "bg-[linear-gradient(120deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)]";

export function ScoreSection() {
  return (
    <section id="score" className="relative py-[clamp(72px,9vw,132px)]">
      <style href="sac-score" precedence="default">{SECTION_CSS}</style>

      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal>
          <SectionHeading eyebrow="The score" title="Your stress, scored" />
          <p className="mt-[18px] max-w-[62ch] text-[clamp(1.0625rem,1.35vw,1.1875rem)] leading-[1.62] text-ink-muted">
            One number a day, built from five signals your iPhone and Apple&nbsp;Watch already measure — with the
            confidence level and the full breakdown, so you can see <em>why</em> it moved.
          </p>
        </div>

        <ul
          role="list"
          data-reveal
          className="mt-[clamp(38px,4.4vw,60px)] mb-[clamp(40px,4.6vw,60px)] grid grid-flow-dense gap-[2px] overflow-hidden rounded-[18px] border border-ink/[0.06] bg-ink/[0.06] min-[420px]:grid-cols-2 min-[960px]:grid-cols-5"
        >
          {FACTORS.map((factor) => (
            <li
              key={factor.id}
              className="bg-white px-5 pt-6 pb-[26px] transition-colors duration-200 hover:bg-[#fafcfe] last:min-[420px]:max-[959px]:col-span-full"
            >
              <svg
                viewBox="0 0 24 24"
                width="30"
                height="30"
                fill="none"
                stroke="var(--accent)"
                strokeWidth="1.6"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
                className="mb-4"
              >
                {FACTOR_ICONS[factor.id]}
              </svg>
              <h3 className="mb-[7px] text-[clamp(1.0625rem,1.4vw,1.2rem)] leading-[1.28] font-semibold tracking-[-0.012em] text-ink">
                {factor.name}
              </h3>
              <p className="text-[0.875rem] leading-[1.5] text-ink-muted">{factor.copy}</p>
            </li>
          ))}
        </ul>

        <div className="grid items-start gap-[clamp(24px,3vw,34px)] min-[900px]:grid-cols-[minmax(0,1.15fr)_minmax(0,1fr)]">
          <div data-reveal className="sac-viz">
            <h3 className="mb-[6px] text-[clamp(1.0625rem,1.4vw,1.2rem)] leading-[1.28] font-semibold tracking-[-0.012em] text-ink">
              Five tiers, one scale
            </h3>
            <p className="max-w-[46ch] text-[0.8125rem] leading-[1.5] text-ink-muted">
              Every score lands in a tier with its own colour, so a glance is enough.
            </p>

            <div className="mt-[6px] flex items-stretch gap-[clamp(8px,1.4vw,18px)] h-[clamp(210px,25vw,268px)]">
              {TIERS.map((tier) => (
                <div key={tier.name} className="sac-tier flex-1 grid min-w-0 grid-cols-1 grid-rows-[auto_minmax(0,1fr)_auto] justify-items-center gap-3">
                  <span style={{ color: tier.color }}>
                    <MoodFace mouth={tier.mouth} />
                  </span>
                  <div className="flex h-full w-full items-end">
                    <div
                      className="sac-tier-bar w-full flex-none rounded-t-[12px] rounded-b-[4px]"
                      style={{ height: `${tier.height}%`, background: tier.color }}
                    />
                  </div>
                  <span className="text-center text-[0.8125rem] leading-[1.2] font-semibold tracking-[-0.005em] text-ink">
                    {tier.name}
                  </span>
                </div>
              ))}
            </div>

            <div className="mt-[14px] flex justify-between border-t border-ink/10 pt-[13px]">
              <span className="font-[family-name:var(--font-mono)] text-[0.6875rem] tracking-[0.08em] text-ink-muted">0 · CALMER</span>
              <span className="font-[family-name:var(--font-mono)] text-[0.6875rem] tracking-[0.08em] text-ink-muted">100 · MORE STRAIN</span>
            </div>
          </div>

          <div data-reveal className="rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(22px,2.6vw,32px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]">
            <div className="mb-[22px] flex items-baseline gap-3 border-b border-ink/[0.06] pb-5">
              <span className="text-[2.9rem] leading-none font-semibold tracking-[-0.04em] text-ink">38</span>
              <span className="text-[0.8125rem] leading-[1.5] text-ink-muted">of 100</span>
              <span className="ml-auto flex items-center gap-2 text-[0.9375rem] font-semibold text-ink">
                <span aria-hidden="true" className="size-2.5 flex-none rounded-full bg-[var(--tier-mild)]" />
                Mild
              </span>
            </div>

            <div className="grid gap-[15px]">
              {BREAKDOWN.map((row) => (
                <div key={row.label} className="sac-bd-row grid grid-cols-[minmax(84px,auto)_1fr_34px] items-center gap-[13px]">
                  <span className="text-[0.875rem] text-ink-muted">{row.label}</span>
                  <div className="h-[7px] overflow-hidden rounded-full bg-surface">
                    <div
                      className={`sac-bd-fill h-full rounded-full ${GRADIENT}`}
                      style={{ width: `${row.value}%`, "--w": `${row.value}%` } as CSSProperties}
                    />
                  </div>
                  <span className="text-right font-[family-name:var(--font-mono)] text-[0.8125rem] text-ink">{row.value}</span>
                </div>
              ))}
            </div>

            <p className="mt-5 border-t border-ink/[0.06] pt-[18px] text-[0.8125rem] leading-[1.5] text-ink-muted">
              Sleep is carrying most of today&rsquo;s score. Confidence is high — all five signals reported.
            </p>

            <p className="mt-[14px] flex items-center gap-[7px] font-[family-name:var(--font-mono)] text-[0.625rem] uppercase tracking-[0.11em] text-ink-muted">
              <span aria-hidden="true" className="size-[5px] flex-none rounded-full bg-accent-bright" />
              Illustrative preview
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
