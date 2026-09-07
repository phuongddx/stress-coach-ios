// "3 of 7" count + thin brand-gradient fill for the one-question-per-screen
// flow. The bar is decorative; the visible "N of 7" text is the accessible
// statement, so the track is hidden from assistive tech.
export function ProgressBar({ current, total }: { current: number; total: number }) {
  return (
    <div>
      <div className="flex items-baseline justify-between">
        <p className="font-[family-name:var(--font-roboto)] text-[0.6875rem] font-medium uppercase tracking-[0.15em] text-accent-deep">
          Question
        </p>
        <p className="font-[family-name:var(--font-roboto)] text-[0.8125rem] tabular-nums text-ink-muted">
          {current} of {total}
        </p>
      </div>
      <div aria-hidden="true" className="mt-2.5 h-1 overflow-hidden rounded-full bg-ink/[0.07]">
        <div
          className="h-full rounded-full bg-[linear-gradient(90deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)] transition-[width] duration-300 ease-out"
          style={{ width: `${Math.round((current / total) * 100)}%` }}
        />
      </div>
    </div>
  );
}
