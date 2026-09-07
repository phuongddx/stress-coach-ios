// Coach chat vignette from sac-landing §5: the full illustrative conversation
// inside one card — header (Ripple mark, "Coach", today's score pill), the
// user/coach bubbles with inline emphasis, the two suggestion chips, and the
// closing exchange. Static; copy and geometry are the design's, verbatim.
import { RippleMark } from "./RippleMark";

const MSG = "max-w-[84%] rounded-[19px] px-[17px] py-[13px] text-[0.9375rem] leading-[1.52]";
const THEM = `${MSG} justify-self-start rounded-bl-[6px] bg-surface text-ink`;
const YOU = `${MSG} justify-self-end rounded-br-[6px] bg-ink text-white`;
const EM = "not-italic font-semibold";

const chipIcon478 = (
    <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="3" />
      <path d="M12 5.4a6.6 6.6 0 0 1 6.6 6.6" />
      <path d="M12 2.2a9.8 9.8 0 0 1 9.8 9.8" />
    </svg>
);

const chipIconWalk = (
    <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M7.6 3.6c1.4 0 2.2 1.4 2.2 3.4s-.6 3.6-2 3.6-2.4-1.6-2.4-3.6.8-3.4 2.2-3.4Z" />
      <path d="M5.4 12.8c1.6-.6 3.2-.4 4.4.4" />
      <path d="M16.4 10.2c1.4 0 2.2 1.4 2.2 3.4s-.6 3.6-2 3.6-2.4-1.6-2.4-3.6.8-3.4 2.2-3.4Z" />
      <path d="M14.2 19.4c1.6-.6 3.2-.4 4.4.4" />
    </svg>
);

export function ChatVignette() {
  return (
    <div className="grid gap-3 rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(18px,2.2vw,24px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]">
      <div className="mb-1 flex items-center gap-[11px] border-b border-ink/[0.06] pb-[15px]">
        <RippleMark size={34} />
        <strong className="text-[0.9375rem] font-semibold text-ink">Coach</strong>
        <span className="ml-auto flex items-center gap-[7px] rounded-full bg-surface px-[11px] py-1.5 font-[family-name:var(--font-mono)] text-[0.6875rem] tracking-[0.05em] text-ink">
          <span aria-hidden="true" className="size-2.5 rounded-full bg-[var(--tier-high)]" />
          Today · 61 High
        </span>
      </div>

      <p className={YOU}>Chest feels tight and I still have two hours of work.</p>
      <p className={THEM}>
        You&rsquo;re at <em className={EM}>61 — High</em> today, mostly from HRV and last night&rsquo;s short sleep. Two more hours is a lot to ask of that.
      </p>
      <p className={THEM}>
        Let&rsquo;s take two minutes off the top: <em className={EM}>4-7-8 breathing</em>, then stand up and walk for five. I&rsquo;ll check your HRV after.
      </p>

      <div className="flex flex-wrap gap-[9px] justify-self-start">
        <span className="inline-flex min-h-[38px] items-center gap-2 rounded-full border-[1.5px] border-accent/35 bg-accent/[0.06] px-[15px] text-[0.8125rem] font-semibold text-accent-deep">
          {chipIcon478}
          Start 4-7-8 · 2 min
        </span>
        <span className="inline-flex min-h-[38px] items-center gap-2 rounded-full border-[1.5px] border-accent/35 bg-accent/[0.06] px-[15px] text-[0.8125rem] font-semibold text-accent-deep">
          {chipIconWalk}
          Log a mini walk
        </span>
      </div>

      <p className={YOU}>ok, doing the breathing now</p>
      <p className={THEM}>Good. I&rsquo;ll leave you to it — check back in when you&rsquo;re done.</p>
    </div>
  );
}
