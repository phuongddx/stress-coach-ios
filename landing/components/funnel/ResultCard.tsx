// Quiz result: the matched stress pattern with its mood face, the app tools
// that target it, the answers that drove the call, and the App Store CTA.
import { AppStoreBadge } from "@/components/AppStoreBadge";
import { PATTERN_INFO } from "@/content/quiz";
import type { QuizResult } from "@/lib/quiz";

// The five mood faces from the design assets
// (assets/images/stress-ai-coach/mood-*.svg), inlined so the card needs no
// runtime fetch. Each renders in its matching tier color (MoodTierStrip palette).
type MoodFaceName = "mood-relaxed" | "mood-mild" | "mood-moderate" | "mood-high" | "mood-severe";

function MoodRelaxed() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <circle cx="15" cy="10" r="1.5" fill="currentColor" />
      <path d="M9 15s1.5 1.5 3 1.5 3-1.5 3-1.5" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
    </svg>
  );
}

function MoodMild() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <circle cx="15" cy="10" r="1.5" fill="currentColor" />
      <path d="M9 15h6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function MoodModerate() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <circle cx="15" cy="10" r="1.5" fill="currentColor" />
      <path d="M9 14h6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function MoodHigh() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <circle cx="15" cy="10" r="1.5" fill="currentColor" />
      <path d="M9 16c1.5-1.5 4.5-1.5 6 0" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
    </svg>
  );
}

function MoodSevere() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <circle cx="9" cy="10" r="1.5" fill="currentColor" />
      <circle cx="15" cy="10" r="1.5" fill="currentColor" />
      <path d="M8 17c2-2 6-2 8 0" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
    </svg>
  );
}

// PATTERN_INFO.moodFace is typed `string` in content/quiz.ts but the data is a
// closed set of these five names; the cast keeps that contract local to here.
const MOOD_FACES: Record<MoodFaceName, { Face: () => React.ReactElement; color: string }> = {
  "mood-relaxed": { Face: MoodRelaxed, color: "var(--tier-relaxed)" },
  "mood-mild": { Face: MoodMild, color: "var(--tier-mild)" },
  "mood-moderate": { Face: MoodModerate, color: "var(--tier-moderate)" },
  "mood-high": { Face: MoodHigh, color: "var(--tier-high)" },
  "mood-severe": { Face: MoodSevere, color: "var(--tier-severe)" },
};

export function ResultCard({ result, onRestart }: { result: QuizResult; onRestart: () => void }) {
  const info = PATTERN_INFO[result.primary];
  const { Face, color } = MOOD_FACES[info.moodFace as MoodFaceName];

  return (
    <section
      aria-labelledby="quiz-result-name"
      className="rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(22px,4vw,32px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_14px_40px_rgba(16,18,35,0.08)]"
    >
      <div className="flex items-center gap-4">
        <span
          aria-hidden="true"
          className="flex size-16 shrink-0 items-center justify-center rounded-full border border-ink/[0.08]"
          style={{ color }}
        >
          <span className="block size-9 [&>svg]:h-full [&>svg]:w-full">
            <Face />
          </span>
        </span>
        <div>
          <p className="text-[0.6875rem] font-medium uppercase tracking-[0.15em] text-accent-deep">Your pattern</p>
          <h2 id="quiz-result-name" className="mt-1 text-[clamp(1.75rem,4.5vw,2.375rem)] font-semibold leading-[1.06] tracking-[-0.028em] text-ink">
            {info.name}
          </h2>
        </div>
      </div>

      <p className="mt-5 text-[1.0625rem] leading-[1.62] text-ink-muted">{info.summary}</p>

      <h3 className="mt-7 text-[1.0625rem] font-semibold tracking-[-0.012em] text-ink">The app starts you with</h3>
      <ul role="list" className="mt-3.5 space-y-2.5">
        {info.coachFocus.map((line) => (
          <li key={line} className="flex items-start gap-3 text-[0.9375rem] leading-[1.55] text-ink">
            <span
              aria-hidden="true"
              className="mt-[0.55em] h-0.5 w-[18px] shrink-0 rounded-full bg-[linear-gradient(90deg,var(--grad-a)_0%,var(--grad-b)_100%)]"
            />
            {line}
          </li>
        ))}
      </ul>

      {result.because.length > 0 && (
        <>
          <h3 className="mt-7 text-[1.0625rem] font-semibold tracking-[-0.012em] text-ink">Your answers point here</h3>
          <ul role="list" className="mt-3.5 space-y-2 border-l-2 border-accent/25 pl-4">
            {result.because.map((answer) => (
              <li key={answer} className="text-[0.9375rem] leading-[1.55] text-ink-muted">
                &ldquo;{answer}&rdquo;
              </li>
            ))}
          </ul>
        </>
      )}

      <div className="mt-8 border-t border-ink/[0.06] pt-7">
        <h3 className="text-[1.0625rem] font-semibold tracking-[-0.012em] text-ink">Start with this plan</h3>
        <p className="mt-1.5 text-[0.8125rem] text-ink-muted">iPhone &amp; Apple Watch — the tools above are in the app.</p>
        <div className="mt-4">
          <AppStoreBadge />
        </div>
        <div className="mt-6 flex flex-wrap items-center gap-x-5 gap-y-2">
          <a
            href="/#score"
            className="text-[0.9375rem] font-semibold text-accent-deep underline decoration-accent-deep/30 underline-offset-4 transition-colors hover:decoration-accent-deep"
          >
            See how the score works
          </a>
          <button
            type="button"
            onClick={onRestart}
            className="text-[0.9375rem] font-semibold text-ink-muted underline decoration-ink-muted/30 underline-offset-4 transition-colors hover:text-ink hover:decoration-ink/40"
          >
            Retake the quiz
          </button>
        </div>
      </div>
    </section>
  );
}
