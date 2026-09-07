// Sticky site nav, ported from sac-landing §1. Server component: the section
// links are anchors, the pill reveal is a CSS scroll-driven animation keyed to
// the hero's view timeline (appears only once the hero CTA has left the
// viewport, matching the design's body.past-hero behavior — scroll-linked
// state, not time-based motion, so it stays on under reduced motion), and the
// mobile sheet is a checkbox-hack. NavSheetList (the one client island)
// unchecks the box on link tap so the sheet collapses like the design's JS;
// the burger/close swap and the toggle's focus ring key off the same checkbox
// via html:has() (Tailwind peer variants only reach siblings, not the nested
// label). Breakpoints follow the design's 900px link/toggle switch.
import { AppStoreBadge } from "@/components/AppStoreBadge";
import { RippleMark } from "@/components/illustrations/RippleMark";
import { NavSheetList } from "./NavSheetList";

const LINKS = [
  ["Score", "#score"],
  ["Coach", "#coach"],
  ["Ripple", "#ripple"],
  ["Calm", "#calm"],
  ["FAQ", "#faq"],
] as const;

const NAV_CSS = `
.sac-nav{position:sticky;top:0;z-index:40;background:rgba(255,255,255,.82);
  backdrop-filter:saturate(180%) blur(18px);-webkit-backdrop-filter:saturate(180%) blur(18px);
  border-bottom:1px solid transparent}
main.sac-page{timeline-scope:--sac-hero}
@supports (animation-timeline: scroll()){
  .sac-nav{animation:sac-nav-border linear both;animation-timeline:scroll();animation-range:0px 90px}
  @keyframes sac-nav-border{to{border-bottom-color:rgba(16,18,35,.10);box-shadow:0 6px 24px rgba(16,18,35,.05)}}
  .sac-nav-cta{animation:sac-navcta-in linear both;animation-timeline:--sac-hero;animation-range:exit 55% exit 100%}
  @keyframes sac-navcta-in{from{opacity:0;transform:translateY(-6px);pointer-events:none}to{opacity:1;transform:none}}
}
@media (prefers-reduced-motion: reduce){
  .sac-nav{animation:none;border-bottom-color:rgba(16,18,35,.10)}
}
html:has(#sac-nav-toggle:focus-visible) .sac-nav-toggle{outline:2px solid var(--accent);outline-offset:2px}
.sac-nav-close{display:none}
html:has(#sac-nav-toggle:checked) .sac-nav-burger{display:none}
html:has(#sac-nav-toggle:checked) .sac-nav-close{display:block}
`;

export function Nav() {
  return (
    <header className="sac-nav">
      <style href="sac-nav" precedence="default">{NAV_CSS}</style>

      <input type="checkbox" id="sac-nav-toggle" className="peer sr-only" />

      <div className="mx-auto flex min-h-[66px] w-full max-w-[1180px] items-center gap-5 px-[clamp(20px,5vw,40px)]">
        <a href="#top" className="mr-auto flex items-center gap-2.5 text-ink no-underline">
          <RippleMark size={32} />
          <span className="whitespace-nowrap text-[1.0625rem] font-semibold tracking-[-0.02em]">
            Stress AI Coach
          </span>
        </a>

        <nav aria-label="Sections" className="hidden min-[900px]:flex items-center gap-1">
          {LINKS.map(([label, href]) => (
            <a
              key={href}
              href={href}
              className="inline-flex min-h-[44px] items-center rounded-[10px] px-[13px] text-[0.9375rem] font-medium text-ink-muted transition-colors duration-150 hover:bg-ink/5 hover:text-ink"
            >
              {label}
            </a>
          ))}
        </nav>

        {/* Hidden below sm: brand + 132px badge + toggle overflow a 390px row. */}
        <div className="sac-nav-cta hidden sm:block">
          <AppStoreBadge className="[&_svg]:w-[132px]" />
        </div>

        <label
          htmlFor="sac-nav-toggle"
          aria-label="Menu"
          className="sac-nav-toggle inline-flex size-[44px] cursor-pointer items-center justify-center rounded-[11px] border border-ink/10 bg-white text-ink transition-colors hover:bg-ink/5 min-[900px]:hidden"
        >
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true" className="sac-nav-burger">
            <path d="M4 8h16M4 16h16" />
          </svg>
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true" className="sac-nav-close">
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </label>
      </div>

      <div className="grid max-h-0 overflow-hidden border-t border-transparent transition-[max-height,border-color] duration-300 min-[900px]:hidden peer-checked:max-h-[340px] peer-checked:border-ink/10">
        <NavSheetList links={LINKS} />
      </div>
    </header>
  );
}
