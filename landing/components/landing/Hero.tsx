// Hero, ported from sac-landing §2. The white→tint settle is a ~1.3s CSS
// animation on load; the drifting bubbles are a static server-rendered set on
// the design's `drift` keyframes. `view-timeline-name` here is what the nav
// pill's scroll-driven reveal is keyed against (see Nav.tsx).
import { AppStoreBadge } from "@/components/AppStoreBadge";
import { ScoreDial } from "@/components/illustrations/ScoreDial";
import { RippleMark } from "@/components/illustrations/RippleMark";
import { siteConfig } from "@/site.config";

const HERO_CSS = `
.sac-hero{view-timeline-name:--sac-hero}
.sac-hero{animation:sac-hero-settle 1.3s cubic-bezier(.3,0,.2,1) both}
@keyframes sac-hero-settle{from{background-color:#fff}to{background-color:var(--tint)}}
@media (prefers-reduced-motion: reduce){.sac-hero{animation:none;background:var(--tint)}}
.sac-bubble{position:absolute;border-radius:50%;
  background:radial-gradient(circle at 32% 28%,rgba(255,255,255,.9),rgba(79,195,247,.42) 62%,rgba(2,136,209,.16));
  animation:sac-drift linear infinite}
@keyframes sac-drift{
  0%{transform:translate3d(0,20px,0) scale(.9);opacity:0}
  12%{opacity:.85}
  88%{opacity:.7}
  100%{transform:translate3d(14px,-140px,0) scale(1.06);opacity:0}
}
@media (prefers-reduced-motion: reduce){.sac-bubbles{display:none}}
`;

const BUBBLES = [
  { left: "6%", size: 22, dur: 16, delay: -3 },
  { left: "18%", size: 14, dur: 12, delay: -8 },
  { left: "37%", size: 34, dur: 19, delay: -1 },
  { left: "58%", size: 18, dur: 13, delay: -10 },
  { left: "74%", size: 46, dur: 17, delay: -5 },
  { left: "90%", size: 24, dur: 14, delay: -12 },
] as const;

export function Hero() {
  return (
    <section className="sac-hero relative overflow-hidden pt-[clamp(56px,7vw,96px)] pb-[clamp(64px,7vw,104px)]">
      <style href="sac-hero" precedence="default">{HERO_CSS}</style>

      <div aria-hidden="true" className="sac-bubbles pointer-events-none absolute inset-0 z-[1] overflow-hidden">
        {BUBBLES.map((b) => (
          <span
            key={b.left}
            className="sac-bubble"
            style={{ left: b.left, width: b.size, height: b.size, animationDuration: `${b.dur}s`, animationDelay: `${b.delay}s` }}
          />
        ))}
      </div>

      <div className="relative z-[2] mx-auto grid w-full max-w-[1180px] items-center gap-[clamp(38px,5vw,56px)] px-[clamp(20px,5vw,40px)] min-[860px]:grid-cols-[minmax(0,1.04fr)_minmax(0,0.96fr)]">
        <div>
          <p className="mb-[18px] flex items-center gap-2.5 font-[family-name:var(--font-mono)] text-[0.6875rem] uppercase tracking-[0.15em] text-accent-deep">
            <span
              aria-hidden="true"
              className="h-0.5 w-[22px] shrink-0 rounded-full bg-[linear-gradient(120deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)]"
            />
            iPhone &amp; Apple Watch
          </p>

          <h1 className="text-[clamp(2.55rem,6.4vw,5rem)] leading-[0.99] font-semibold tracking-[-0.032em] text-ink">
            Understand your stress.
            <br />
            Do something about it.
          </h1>

          <p className="mt-[22px] max-w-[46ch] text-[clamp(1.0625rem,1.35vw,1.1875rem)] leading-[1.62] text-[color:var(--muted-tint)]">
            Stress AI Coach reads the health data your iPhone already collects and turns it into one daily stress score
            &mdash; then helps you actually act on it.
          </p>

          <div className="mt-[34px] flex flex-wrap items-center gap-3.5">
            <AppStoreBadge />
            <a
              href={siteConfig.quizPath}
              className="group inline-flex min-h-[48px] items-center gap-[9px] rounded-full border-[1.5px] border-ink/[0.22] px-[22px] text-[0.9375rem] font-semibold text-ink transition-[background-color,border-color] duration-200 hover:border-ink/40 hover:bg-ink/[0.055]"
            >
              Take the 60-second stress quiz
              <svg
                viewBox="0 0 24 24"
                width="18"
                height="18"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
                className="transition-transform duration-200 group-hover:translate-x-[3px]"
              >
                <path d="M4.6 12h14.4M13.4 6.4l5.6 5.6-5.6 5.6" />
              </svg>
            </a>
          </div>

          <p className="mt-[18px] text-[0.8125rem] text-[color:var(--muted-tint)]">
            Scoring runs on your device. Not a medical device.
          </p>
        </div>

        <div className="relative grid place-items-center min-[860px]:min-h-[clamp(320px,38vw,460px)]">
          <ScoreDial score={38} />
          <div
            aria-hidden="true"
            className="pointer-events-none absolute right-[-2%] bottom-[-2%] w-[clamp(112px,15vw,178px)] [filter:drop-shadow(0_18px_34px_rgba(2,136,209,0.24))] [&>svg]:h-auto [&>svg]:w-full"
          >
            <RippleMark size={178} />
          </div>
        </div>
      </div>
    </section>
  );
}
