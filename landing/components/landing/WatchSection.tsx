// "At a glance, all day" (wrist + widgets), ported from sac-landing §9: the
// dark band with Task 3's WatchGlyph, the two widget cards, and the
// watch/widgets/complications list. The heading is hand-rolled rather than
// SectionHeading because the design's dark band recolors the eyebrow
// (--accent-bright) and text.
import type { ReactNode } from "react";
import { WatchGlyph } from "@/components/illustrations/WatchGlyph";

// Stroke icon paths from the design's sprite (i-watch / i-widget / i-clock).
const LIST_ICONS = {
  watch: <><rect x="6.2" y="6.2" width="11.6" height="11.6" rx="3.4" /><path d="M9.2 6.2 9.8 2.6h4.4l.6 3.6M9.2 17.8l.6 3.6h4.4l.6-3.6" /><path d="M17.8 10.6h1.6" /></>,
  widget: <><rect x="3" y="3" width="8" height="8" rx="2.2" /><rect x="13" y="3" width="8" height="8" rx="2.2" /><rect x="3" y="13" width="18" height="8" rx="2.2" /></>,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5.2l3.4 2" /></>,
} as const;

function ListIcon({ paths }: { paths: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="24"
      height="24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className="mt-[2px] flex-none text-accent-bright"
    >
      {paths}
    </svg>
  );
}

const WRIST_ITEMS = [
  {
    id: "watch",
    lead: "Apple Watch app.",
    copy: " Your score and tier on your wrist, plus the shortest calm tools without reaching for your phone.",
  },
  {
    id: "widget",
    lead: "iPhone widgets.",
    copy: " Today's score and your seven-day shape on the home screen — no app launch needed.",
  },
  {
    id: "clock",
    lead: "Complications.",
    copy: " Put the score straight on your watch face, next to everything else you check.",
  },
] as const;

export function WatchSection() {
  return (
    <section className="bg-ink py-[clamp(72px,9vw,132px)] text-white">
      <div className="mx-auto grid w-full max-w-[1180px] items-center gap-[clamp(32px,4.4vw,60px)] px-[clamp(20px,5vw,40px)] min-[900px]:grid-cols-[minmax(0,1fr)_minmax(0,1.02fr)]">
        <div data-reveal className="flex flex-wrap items-center justify-center gap-[clamp(16px,2.6vw,30px)]">
          <div className="w-[min(100%,208px)] flex-none">
            <WatchGlyph score={38} />
          </div>

          <div className="grid w-[min(100%,206px)] flex-none gap-[14px]">
            <div className="rounded-[18px] border border-white/15 bg-white/[0.07] px-[17px] py-4">
              <span className="font-[family-name:var(--font-mono)] text-[0.5625rem] uppercase tracking-[0.12em] text-white/60">
                Stress today
              </span>
              <div className="mt-[7px] text-[2.2rem] leading-none font-semibold tracking-[-0.03em]">38</div>
              <div className="mt-[5px] flex items-center gap-[7px] text-[0.75rem] font-semibold">
                <span aria-hidden="true" className="size-2.5 flex-none rounded-full bg-[color:var(--tier-mild)]" />
                Mild
              </div>
            </div>
            <div className="rounded-[18px] border border-white/15 bg-white/[0.07] px-[17px] py-4">
              <span className="font-[family-name:var(--font-mono)] text-[0.5625rem] uppercase tracking-[0.12em] text-white/60">
                Last 7 days
              </span>
              <svg viewBox="0 0 160 46" aria-hidden="true" className="mt-[11px] block h-auto w-full">
                <path
                  d="M4 34 L30 27 L56 38 L82 14 L108 20 L134 30 L156 36"
                  fill="none"
                  stroke="var(--accent-bright)"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <circle cx="156" cy="36" r="4.5" fill="var(--accent-bright)" />
              </svg>
            </div>
          </div>
        </div>

        <div data-reveal>
          <p className="mb-[18px] flex items-center gap-2.5 font-[family-name:var(--font-mono)] text-[0.6875rem] uppercase tracking-[0.15em] text-accent-bright">
            <span
              aria-hidden="true"
              className="h-0.5 w-[22px] shrink-0 rounded-full bg-[linear-gradient(120deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)]"
            />
            On your wrist
          </p>
          <h2 className="text-[clamp(1.95rem,3.7vw,3rem)] leading-[1.06] font-semibold tracking-[-0.028em] text-white">
            At a glance, all day
          </h2>
          <ul role="list" className="mt-[28px] grid gap-[14px]">
            {WRIST_ITEMS.map((item) => (
              <li key={item.id} className="flex items-start gap-[13px]">
                <ListIcon paths={LIST_ICONS[item.id]} />
                <p className="text-[0.9375rem] leading-[1.55] text-white/78">
                  <strong className="font-semibold text-white">{item.lead}</strong>
                  {item.copy}
                </p>
              </li>
            ))}
          </ul>
          <p className="mt-[14px] flex items-center gap-[7px] font-[family-name:var(--font-mono)] text-[0.625rem] uppercase tracking-[0.11em] text-white/60">
            <span aria-hidden="true" className="size-[5px] flex-none rounded-full bg-accent-bright" />
            Illustrative preview
          </p>
        </div>
      </div>
    </section>
  );
}
