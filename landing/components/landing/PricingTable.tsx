// "Free vs Premium", ported from sac-landing §12: the comparison table. The
// split is the honest one — the free tier genuinely covers the daily score and
// basic trends; no discounts, no fake urgency. The "Premium" column keeps the
// design's subtle tint; "—" cells carry an sr-only "Not included" label.
import { SectionHeading } from "@/components/SectionHeading";

type Cell = { kind: "yes" } | { kind: "no" } | { kind: "text"; text: string };

const ROWS: Array<{ feature: string; free: Cell; premium: Cell }> = [
  { feature: "Daily stress score (0–100)", free: { kind: "yes" }, premium: { kind: "yes" } },
  { feature: "Five-factor breakdown & confidence", free: { kind: "yes" }, premium: { kind: "yes" } },
  { feature: "Mood check-ins", free: { kind: "yes" }, premium: { kind: "yes" } },
  { feature: "Trends", free: { kind: "text", text: "Basic" }, premium: { kind: "text", text: "7 / 30 / 90-day + full history" } },
  { feature: "AI coach chat", free: { kind: "text", text: "Limited" }, premium: { kind: "text", text: "Unlimited" } },
  { feature: "Calm tools", free: { kind: "text", text: "Core set" }, premium: { kind: "text", text: "Every tool" } },
  { feature: "Apple Watch app", free: { kind: "no" }, premium: { kind: "yes" } },
  { feature: "Widgets & complications", free: { kind: "no" }, premium: { kind: "yes" } },
  { feature: "Companions", free: { kind: "text", text: "Ripple" }, premium: { kind: "text", text: "Ripple + all four unlockables" } },
];

function CheckMark() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="19"
      height="19"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className="inline-block align-[-3px]"
    >
      {/* i-check from the design's sprite */}
      <path d="M4.8 12.6l4.6 4.6L19.2 7.4" />
    </svg>
  );
}

function PlanCell({ cell, pro }: { cell: Cell; pro?: boolean }) {
  return (
    <td className={"w-[30%] px-[clamp(10px,1.5vw,20px)] py-[15px] text-center align-middle text-[0.875rem] max-[560px]:w-[31%] max-[560px]:px-[9px] max-[560px]:py-[13px] max-[560px]:text-[0.8125rem]" + (pro ? " bg-accent/[0.035]" : "")}>
      {cell.kind === "yes" && <span className="text-accent-deep"><CheckMark /><span className="sr-only">Included</span></span>}
      {cell.kind === "no" && (
        <span className="text-[1.05rem] text-ink/30">
          —<span className="sr-only">Not included</span>
        </span>
      )}
      {cell.kind === "text" && cell.text}
    </td>
  );
}

export function PricingTable() {
  return (
    <section className="py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal>
          <SectionHeading
            eyebrow="Plans"
            title="Free vs Premium"
            lede="The daily score is free, permanently. Premium opens up unlimited coaching, every calm tool, your full history, and the watch and widget surfaces."
          />
        </div>

        <div
          data-reveal
          className="overflow-hidden rounded-[24px] border border-ink/10 bg-white shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]"
        >
          <table className="w-full border-collapse text-[0.9375rem]">
            <caption className="px-[clamp(10px,1.5vw,20px)] py-[15px] text-left text-[0.8125rem] leading-[1.5] text-ink-muted">
              What's in each tier
            </caption>
            <thead>
              <tr>
                <th
                  scope="col"
                  className="border-b border-ink/[0.06] bg-surface-warm px-[clamp(10px,1.5vw,20px)] py-[15px] text-left align-middle font-[family-name:var(--font-mono)] text-[0.6875rem] font-normal uppercase tracking-[0.11em] text-ink-muted max-[560px]:px-[9px] max-[560px]:py-[13px]"
                >
                  Feature
                </th>
                <th
                  scope="col"
                  className="border-b border-ink/[0.06] bg-surface-warm px-[clamp(10px,1.5vw,20px)] py-[15px] text-center align-middle font-[family-name:var(--font-mono)] text-[0.6875rem] font-normal uppercase tracking-[0.11em] text-ink-muted max-[560px]:px-[9px] max-[560px]:py-[13px]"
                >
                  Free
                </th>
                <th
                  scope="col"
                  className="border-b border-ink/[0.06] bg-accent/[0.06] px-[clamp(10px,1.5vw,20px)] py-[15px] text-center align-middle font-[family-name:var(--font-mono)] text-[0.6875rem] font-normal uppercase tracking-[0.11em] text-accent-deep max-[560px]:px-[9px] max-[560px]:py-[13px]"
                >
                  Premium
                </th>
              </tr>
            </thead>
            <tbody>
              {ROWS.map((row) => (
                <tr key={row.feature} className="[&>th]:border-b [&>th]:border-ink/[0.06] [&>td]:border-b [&>td]:border-ink/[0.06] last:[&>th]:border-b-0 last:[&>td]:border-b-0">
                  <th
                    scope="row"
                    className="w-[40%] px-[clamp(10px,1.5vw,20px)] py-[15px] text-left align-middle font-medium text-ink max-[560px]:w-[38%] max-[560px]:px-[9px] max-[560px]:py-[13px] max-[560px]:text-[0.875rem]"
                  >
                    {row.feature}
                  </th>
                  <PlanCell cell={row.free} />
                  <PlanCell cell={row.premium} pro />
                </tr>
              ))}
            </tbody>
          </table>
          <p className="border-t border-ink/[0.06] bg-surface-warm px-[clamp(14px,1.6vw,20px)] py-[18px] text-[0.8125rem] leading-[1.5] text-ink-muted">
            Premium is available weekly, monthly or yearly. Manage or cancel any time in your Apple&nbsp;ID subscription settings.
          </p>
        </div>
      </div>
    </section>
  );
}
