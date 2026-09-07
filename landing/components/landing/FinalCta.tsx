// Final CTA, ported from sac-landing §14: tinted band, Ripple mark, the
// closing line, and the two CTAs (App Store badge + quiz button). The
// design's drifting bubbles are server-rendered as a static set on the hero's
// drift keyframes; they're hidden under prefers-reduced-motion.
import { AppStoreBadge } from "@/components/AppStoreBadge";
import { RippleMark } from "@/components/illustrations/RippleMark";
import { siteConfig } from "@/site.config";

const FINAL_CSS = `
.sac-fbubble{position:absolute;border-radius:50%;
  background:radial-gradient(circle at 32% 28%,rgba(255,255,255,.9),rgba(79,195,247,.42) 62%,rgba(2,136,209,.16));
  animation:sac-drift linear infinite}
@keyframes sac-drift{
  0%{transform:translate3d(0,20px,0) scale(.9);opacity:0}
  12%{opacity:.85}
  88%{opacity:.7}
  100%{transform:translate3d(14px,-140px,0) scale(1.06);opacity:0}
}
@media (prefers-reduced-motion: reduce){.sac-fbubbles{display:none}}
`;

const BUBBLES = [
  { left: "9%", size: 26, dur: 17, delay: -4 },
  { left: "26%", size: 15, dur: 13, delay: -9 },
  { left: "47%", size: 36, dur: 20, delay: -2 },
  { left: "66%", size: 17, dur: 14, delay: -11 },
  { left: "83%", size: 44, dur: 18, delay: -6 },
] as const;

export function FinalCta() {
  return (
    <section id="download" className="sac-final relative overflow-hidden bg-tint py-[clamp(72px,9vw,132px)] text-center">
      <style href="sac-final" precedence="default">{FINAL_CSS}</style>

      <div aria-hidden="true" className="sac-fbubbles pointer-events-none absolute inset-0 z-[1] overflow-hidden">
        {BUBBLES.map((b, i) => (
          <span
            key={i}
            className="sac-fbubble"
            style={{
              left: b.left,
              bottom: `${(i * 37) % 60}px`,
              width: `${b.size}px`,
              height: `${b.size}px`,
              animationDuration: `${b.dur}s`,
              animationDelay: `${b.delay}s`,
            }}
          />
        ))}
      </div>

      <div data-reveal className="relative z-[2] mx-auto max-w-[660px] px-[clamp(20px,5vw,40px)]">
        <div aria-hidden="true" className="mx-auto mb-[26px] w-[78px]">
          <RippleMark size={78} />
        </div>
        <h2 className="text-[clamp(1.95rem,3.7vw,3rem)] leading-[1.06] font-semibold tracking-[-0.028em] text-ink">
          Understand your stress.
          <br />
          Do something about it.
        </h2>
        <p className="mx-auto mt-5 max-w-[62ch] text-[clamp(1.0625rem,1.35vw,1.1875rem)] leading-[1.62] text-[color:var(--muted-tint)]">
          One score a day, a coach that knows your context, and a small companion that notices when you&apos;re doing better.
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-3.5">
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
      </div>
    </section>
  );
}
