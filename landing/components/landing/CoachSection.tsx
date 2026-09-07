// "A coach that knows your context", ported from sac-landing §5: the copy
// column with the derived-scores privacy note, and the chat vignette card
// (Task 3's ChatVignette) with the illustrative-preview caption.
import { ChatVignette } from "@/components/illustrations/ChatVignette";
import { SectionHeading } from "@/components/SectionHeading";

export function CoachSection() {
  return (
    <section id="coach" className="bg-surface-warm py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto grid w-full max-w-[1180px] items-center gap-[clamp(30px,4vw,54px)] px-[clamp(20px,5vw,40px)] min-[900px]:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]">
        <div data-reveal>
          <SectionHeading
            eyebrow="The coach"
            title="A coach that knows your context"
            lede="Most wellness chat starts from nothing. This one already knows your readings, your trend, and the patterns it has seen — so instead of generic advice you get one concrete thing to do in the next five minutes: breathe, move, or reflect."
          />

          <div className="mt-[26px] flex items-start gap-3.5 rounded-[18px] border border-accent/[0.18] bg-accent/[0.07] px-[21px] py-[19px]">
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
              className="mt-px flex-none text-accent-deep"
            >
              <path d="M12 2.8 20 5.6v6c0 4.6-3.4 8-8 9.6-4.6-1.6-8-5-8-9.6v-6Z" />
              <path d="M8.8 12.2l2.4 2.4 4.2-4.6" />
            </svg>
            <p className="text-[0.9375rem] leading-[1.55] text-ink">
              The coach only ever sees <strong>derived scores</strong> — never your raw health data. Health sync is
              consent-gated and you can revoke it at any time.
            </p>
          </div>
        </div>

        <div data-reveal>
          <ChatVignette />
          <p className="mt-[14px] flex items-center gap-[7px] font-[family-name:var(--font-mono)] text-[0.625rem] uppercase tracking-[0.11em] text-ink-muted">
            <span aria-hidden="true" className="size-[5px] flex-none rounded-full bg-accent-bright" />
            Illustrative preview
          </p>
        </div>
      </div>
    </section>
  );
}
