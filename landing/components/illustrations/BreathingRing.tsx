// Breathing ring from sac-landing §7 ("Try it now"), reworked as a pure-CSS
// loop: the core scales through the box-breathing shape — expand, hold,
// contract, hold — on one 8s keyframe animation. The original drove phases
// with JS + data attributes; a static server component can't, so the holds are
// flat keyframe segments instead (see task report). The global
// prefers-reduced-motion guard in app/globals.css collapses the animation, and
// the local guard below stops it outright so the core rests mid-scale.
const RING_CSS = `
.sac-ring-stage{position:relative;width:min(100%,262px);aspect-ratio:1;margin-inline:auto;display:grid;place-items:center}
.sac-ring-halo,.sac-ring-core{position:absolute;border-radius:50%}
.sac-ring-halo{inset:0;background:rgba(2,136,209,.07)}
.sac-ring-core{width:56%;height:56%;background:linear-gradient(120deg,var(--grad-a) 0%,var(--grad-b) 55%,var(--grad-c) 100%);box-shadow:0 12px 40px rgba(2,136,209,.34);animation:sac-breathe 8s ease-in-out infinite}
.sac-ring-count{position:relative;z-index:2;font-family:var(--font-roboto),sans-serif;font-size:2.6rem;font-weight:600;color:#fff;line-height:1;text-shadow:0 1px 10px rgba(16,18,35,.28)}
@keyframes sac-breathe{0%{transform:scale(.62)}25%{transform:scale(1)}50%{transform:scale(1)}75%,100%{transform:scale(.62)}}
@media (prefers-reduced-motion:reduce){.sac-ring-core{animation:none;transform:scale(.82)}}
`;

export function BreathingRing({ label = "Box breathing" }: { label?: string }) {
  return (
    <div className="text-center">
      <style href="sac-breathing-ring" precedence="default">{RING_CSS}</style>
      <div className="sac-ring-stage" aria-hidden="true">
        <div className="sac-ring-halo" />
        <div className="sac-ring-core" />
        <span className="sac-ring-count">4</span>
      </div>
      <p className="mt-[22px] text-[1.0625rem] font-semibold leading-snug tracking-[-0.01em] text-ink">{label}</p>
      <p className="mt-[5px] text-[0.8125rem] text-ink-muted">Four in · four hold · four out · four hold</p>
    </div>
  );
}
