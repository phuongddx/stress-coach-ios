// "Before you download" (FAQ), ported from sac-landing §13: a centered
// heading over a native <details> accordion — zero JS; the browser owns open
// state. Questions/answers come from content/faq.ts. The plus sign rotates
// into a close mark via the group-open variant.
import { FAQ_ENTRIES } from "@/content/faq";
import { SectionHeading } from "@/components/SectionHeading";

// SectionHeading's eyebrow row is left-aligned by default; the design centers
// it in this section (descendant beats the utility's single-class selector).
const CENTER_CSS = `.sac-faq-head p{justify-content:center}`;

export function Faq() {
  return (
    <section id="faq" className="bg-surface-warm py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal className="sac-faq-head mx-auto max-w-[660px] text-center">
          <SectionHeading eyebrow="Questions" title="Before you download" />
          <style href="sac-faq-center" precedence="default">{CENTER_CSS}</style>
        </div>

        <div data-reveal className="mx-auto max-w-[840px] border-t border-ink/10">
          {FAQ_ENTRIES.map((entry) => (
            <details key={entry.q} className="group border-b border-ink/10">
              <summary className="flex cursor-pointer list-none items-start gap-4 py-[22px] pl-0.5 pr-0.5 text-[clamp(1.0625rem,1.5vw,1.1875rem)] leading-[1.35] font-semibold tracking-[-0.018em] text-ink transition-colors duration-200 hover:text-accent-deep [&::-webkit-details-marker]:hidden">
                {entry.q}
                <svg
                  viewBox="0 0 24 24"
                  width="22"
                  height="22"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.6"
                  strokeLinecap="round"
                  aria-hidden="true"
                  className="ml-auto mt-[3px] flex-none text-ink-muted transition-[transform,color] duration-300 group-open:rotate-45 group-open:text-accent-deep"
                >
                  {/* i-plus from the design's sprite */}
                  <path d="M12 5.2v13.6M5.2 12h13.6" />
                </svg>
              </summary>
              <p className="pr-[42px] pb-6 pl-0.5 text-[0.9375rem] leading-[1.62] text-ink-muted">{entry.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
