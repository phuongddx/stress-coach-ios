// "See your patterns", ported from sac-landing §8: the sticky copy column,
// the daily-score chart card (Task 3's TrendWave), the time-by-tier rows and
// the weekly calendar strip. The design's 7/30/90-day tab switcher is JS —
// omitted on this static page; the 7-day illustrative view carries the story
// and the lede names the longer ranges. Tier fills and day cells animate in
// via CSS view-timelines (no JS observer); without scroll-driven-animation
// support — or under prefers-reduced-motion — they render in their final
// state.
import type { CSSProperties } from "react";
import { TrendWave } from "@/components/illustrations/TrendWave";
import { SectionHeading } from "@/components/SectionHeading";

const SECTION_CSS = `
@supports (animation-timeline: view()){
  .sac-ttime{view-timeline-name:--sac-ttime}
  .sac-tt-fill{animation:sac-tt-grow 1s cubic-bezier(.22,.68,.16,1) both;animation-timeline:--sac-ttime}
  .sac-tt-row:nth-child(1) .sac-tt-fill{animation-range:entry 0% entry 50%}
  .sac-tt-row:nth-child(2) .sac-tt-fill{animation-range:entry 8% entry 58%}
  .sac-tt-row:nth-child(3) .sac-tt-fill{animation-range:entry 16% entry 66%}
  .sac-tt-row:nth-child(4) .sac-tt-fill{animation-range:entry 24% entry 74%}
  .sac-tt-row:nth-child(5) .sac-tt-fill{animation-range:entry 32% entry 82%}
  .sac-week{view-timeline-name:--sac-week}
  .sac-day-cell{animation:sac-day-in .5s cubic-bezier(.22,.68,.16,1) both;animation-timeline:--sac-week}
  .sac-day:nth-child(1) .sac-day-cell{animation-range:entry 0% entry 45%}
  .sac-day:nth-child(2) .sac-day-cell{animation-range:entry 6% entry 51%}
  .sac-day:nth-child(3) .sac-day-cell{animation-range:entry 12% entry 57%}
  .sac-day:nth-child(4) .sac-day-cell{animation-range:entry 18% entry 63%}
  .sac-day:nth-child(5) .sac-day-cell{animation-range:entry 24% entry 69%}
  .sac-day:nth-child(6) .sac-day-cell{animation-range:entry 30% entry 75%}
  .sac-day:nth-child(7) .sac-day-cell{animation-range:entry 36% entry 81%}
}
@keyframes sac-tt-grow{from{width:0}to{width:var(--w)}}
@keyframes sac-day-in{from{opacity:0;transform:scale(.85)}to{opacity:1;transform:none}}
@media (prefers-reduced-motion: reduce){
  .sac-tt-fill{animation:none;width:var(--w)}
  .sac-day-cell{animation:none;opacity:1;transform:none}
}
`;

// The design's illustrative 7-day series (TrendWave's default shape).
const SERIES = [34, 41, 28, 52, 47, 38, 31];

const LEGEND = [
  { label: "Relaxed", color: "var(--tier-relaxed)" },
  { label: "Mild", color: "var(--tier-mild)" },
  { label: "Elevated", color: "var(--tier-moderate)" },
  { label: "High", color: "var(--tier-high)" },
  { label: "Severe", color: "var(--tier-severe)" },
] as const;

const TIME_BY_TIER = [
  { label: "Relaxed", color: "var(--tier-relaxed)", width: "22%" },
  { label: "Mild", color: "var(--tier-mild)", width: "34%" },
  { label: "Elevated", color: "var(--tier-moderate)", width: "28%" },
  { label: "High", color: "var(--tier-high)", width: "13%" },
  { label: "Severe", color: "var(--tier-severe)", width: "3%" },
] as const;

const WEEK = [
  { label: "M", color: "var(--tier-mild)" },
  { label: "T", color: "var(--tier-moderate)" },
  { label: "W", color: "var(--tier-mild)" },
  { label: "T", color: "var(--tier-high)" },
  { label: "F", color: "var(--tier-moderate)" },
  { label: "S", color: "var(--tier-relaxed)" },
  { label: "S", color: "var(--tier-mild)" },
] as const;

function PreviewCaption({ className = "" }: { className?: string }) {
  return (
    <p
      className={
        "mt-[14px] flex items-center gap-[7px] font-[family-name:var(--font-mono)] text-[0.625rem] uppercase tracking-[0.11em] text-ink-muted " +
        className
      }
    >
      <span aria-hidden="true" className="size-[5px] flex-none rounded-full bg-accent-bright" />
      Illustrative preview
    </p>
  );
}

export function PatternsSection() {
  const avg = Math.round(SERIES.reduce((a, b) => a + b, 0) / SERIES.length);

  return (
    <section className="bg-surface-warm py-[clamp(72px,9vw,132px)]">
      <style href="sac-patterns" precedence="default">{SECTION_CSS}</style>
      <div className="mx-auto grid w-full max-w-[1180px] items-start gap-[clamp(30px,4vw,56px)] px-[clamp(20px,5vw,40px)] min-[1000px]:grid-cols-[minmax(0,0.82fr)_minmax(0,1.18fr)]">
        <div data-reveal className="min-[1000px]:sticky min-[1000px]:top-[110px]">
          <SectionHeading
            eyebrow="The pattern"
            title="See your patterns"
            lede="A single day is noise. Seven, thirty and ninety days are a pattern — which weekdays cost you, how long you actually spend in each tier, and whether last month's changes are holding."
          />
        </div>

        <div className="grid gap-[18px]">
          <div
            data-reveal
            className="rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(20px,2.4vw,28px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]"
          >
            <div className="mb-[6px] flex items-baseline gap-2.5">
              <h3 className="text-[0.9375rem] font-semibold text-ink">Daily score</h3>
              <span className="ml-auto font-[family-name:var(--font-mono)] text-[0.8125rem] text-ink-muted">avg {avg}</span>
            </div>
            <TrendWave points={SERIES} />
            <ul role="list" className="mt-4 flex flex-wrap gap-x-4 gap-y-[7px] border-t border-ink/[0.06] pt-[15px]">
              {LEGEND.map((t) => (
                <li key={t.label} className="flex items-center gap-[7px] text-[0.75rem] text-ink-muted">
                  <span aria-hidden="true" className="size-2.5 flex-none rounded-full" style={{ background: t.color }} />
                  {t.label}
                </li>
              ))}
            </ul>
            <PreviewCaption />
          </div>

          <div className="grid gap-[18px] min-[640px]:grid-cols-2">
            <div
              data-reveal
              className="sac-ttime rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(22px,2.6vw,32px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]"
            >
              <h3 className="text-[clamp(1.0625rem,1.4vw,1.2rem)] leading-[1.28] font-semibold tracking-[-0.012em] text-ink">
                Time by tier
              </h3>
              <p className="mt-[5px] text-[0.8125rem] leading-[1.5] text-ink-muted">Where the last seven days actually went.</p>
              <div className="mt-4 grid gap-[11px]">
                {TIME_BY_TIER.map((t) => (
                  <div key={t.label} className="sac-tt-row grid grid-cols-[74px_1fr_38px] items-center gap-[11px]">
                    <span className="text-[0.8125rem] text-ink-muted">{t.label}</span>
                    <div className="h-[9px] overflow-hidden rounded-full bg-surface">
                      <div
                        className="sac-tt-fill h-full rounded-full"
                        style={{ "--w": t.width, background: t.color } as CSSProperties}
                      />
                    </div>
                    <span className="text-right font-[family-name:var(--font-mono)] text-[0.75rem] text-ink">{t.width}</span>
                  </div>
                ))}
              </div>
              <PreviewCaption />
            </div>

            <div
              data-reveal
              className="sac-week rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(22px,2.6vw,32px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]"
            >
              <h3 className="text-[clamp(1.0625rem,1.4vw,1.2rem)] leading-[1.28] font-semibold tracking-[-0.012em] text-ink">
                This week
              </h3>
              <p className="mt-[5px] text-[0.8125rem] leading-[1.5] text-ink-muted">Tier colour per day, Monday to Sunday.</p>
              <div className="mt-4 grid grid-cols-7 gap-[7px]">
                {WEEK.map((d, i) => (
                  <div key={i} className="sac-day text-center">
                    <div className="sac-day-cell h-[clamp(46px,6vw,64px)] rounded-[11px]" style={{ background: d.color }} />
                    <span className="mt-2 block font-[family-name:var(--font-mono)] text-[0.625rem] tracking-[0.06em] text-ink-muted">
                      {d.label}
                    </span>
                  </div>
                ))}
              </div>
              <p className="mt-[18px] text-[0.8125rem] leading-[1.5] text-ink-muted">Thursday ran high three weeks straight.</p>
              <PreviewCaption />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
