// Section heading block from sac-landing's .sect-head pattern: optional
// gradient-dashed eyebrow in mono caps, display-weight title, optional muted
// lede. One-liner aside: the design tints the eyebrow with its darkened
// --accent-deep; the landing token set only carries --accent, so that's what
// the eyebrow uses here.
export function SectionHeading({ eyebrow, title, lede }: { eyebrow?: string; title: string; lede?: string }) {
  return (
    <div className="max-w-[660px]">
      {eyebrow && (
        <p className="mb-[18px] flex items-center gap-2.5 font-[family-name:var(--font-mono)] text-[0.6875rem] uppercase tracking-[0.15em] text-accent">
          <span
            aria-hidden="true"
            className="h-0.5 w-[22px] shrink-0 rounded-full bg-[linear-gradient(120deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)]"
          />
          {eyebrow}
        </p>
      )}
      <h2 className="text-[clamp(1.95rem,3.7vw,3rem)] font-semibold leading-[1.06] tracking-[-0.028em] text-ink">{title}</h2>
      {lede && (
        <p className="mt-[18px] max-w-[62ch] text-[clamp(1.0625rem,1.35vw,1.1875rem)] leading-[1.62] text-ink-muted">{lede}</p>
      )}
    </div>
  );
}
