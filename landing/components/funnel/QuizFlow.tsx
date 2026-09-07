"use client";

// /start funnel state machine: intro → questions (one per screen) → computing
// → result. Answers live in component state only — no localStorage, no
// network; scoreQuiz runs client-side (lib/quiz.ts, pure).
import { useEffect, useRef, useState } from "react";
import { BreathingRing } from "@/components/illustrations/BreathingRing";
import { RippleMark } from "@/components/illustrations/RippleMark";
import { ProgressBar } from "@/components/funnel/ProgressBar";
import { ResultCard } from "@/components/funnel/ResultCard";
import { QUIZ_QUESTIONS } from "@/content/quiz";
import { scoreQuiz, type AnswerMap, type QuizResult } from "@/lib/quiz";

const ADVANCE_MS = 150;
const COMPUTE_MS = 1200;

type Phase = "intro" | "questions" | "computing" | "result";

export function QuizFlow() {
  const [phase, setPhase] = useState<Phase>("intro");
  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState<AnswerMap>({});
  const [selected, setSelected] = useState<string | null>(null);
  const [result, setResult] = useState<QuizResult | null>(null);
  const advanceTimer = useRef<number | null>(null);
  const computeTimer = useRef<number | null>(null);
  const promptRef = useRef<HTMLHeadingElement | null>(null);

  const clearTimers = () => {
    if (advanceTimer.current) window.clearTimeout(advanceTimer.current);
    if (computeTimer.current) window.clearTimeout(computeTimer.current);
  };

  useEffect(() => clearTimers, []);

  // Each question starts anchored at the top with focus on its prompt, so
  // keyboard and screen-reader users land on the new screen, not mid-scroll.
  useEffect(() => {
    if (phase === "questions") {
      window.scrollTo(0, 0);
      promptRef.current?.focus({ preventScroll: true });
    } else if (phase === "result") {
      window.scrollTo(0, 0);
    }
  }, [phase, step]);

  function choose(questionId: string, optionId: string) {
    if (selected !== null) return; // ignore taps during the advance window
    setSelected(optionId);
    const next = { ...answers, [questionId]: optionId };
    setAnswers(next);
    advanceTimer.current = window.setTimeout(() => {
      setSelected(null);
      if (step + 1 < QUIZ_QUESTIONS.length) {
        setStep(step + 1);
      } else {
        setPhase("computing");
        computeTimer.current = window.setTimeout(() => {
          setResult(scoreQuiz(next));
          setPhase("result");
        }, COMPUTE_MS);
      }
    }, ADVANCE_MS);
  }

  function goBack() {
    clearTimers();
    setSelected(null);
    if (step === 0) {
      setAnswers({});
      setPhase("intro");
    } else {
      setStep(step - 1);
    }
  }

  function restart() {
    clearTimers();
    setSelected(null);
    setAnswers({});
    setStep(0);
    setResult(null);
    setPhase("intro");
  }

  return (
    <div className="min-h-dvh bg-white">
      <header className="mx-auto w-full max-w-[640px] px-[clamp(20px,5vw,40px)] pt-[clamp(20px,3.5vw,32px)]">
        <a
          href="/"
          className="inline-flex items-center gap-2 text-[0.9375rem] font-semibold text-ink transition-opacity hover:opacity-80"
        >
          <RippleMark size={26} />
          Stress AI Coach
        </a>
      </header>

      <main className="mx-auto w-full max-w-[640px] px-[clamp(20px,5vw,40px)] pt-[clamp(30px,5vw,60px)] pb-[clamp(72px,9vw,128px)]">
        {phase === "intro" && (
          <section>
            <p className="mb-[18px] flex items-center gap-2.5 text-[0.6875rem] font-medium uppercase tracking-[0.15em] text-accent-deep">
              <span
                aria-hidden="true"
                className="h-0.5 w-[22px] shrink-0 rounded-full bg-[linear-gradient(120deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)]"
              />
              60-second quiz
            </p>
            <h1 className="text-[clamp(2.35rem,6vw,3.5rem)] font-semibold leading-[1.02] tracking-[-0.032em] text-ink">
              What&rsquo;s your stress pattern?
            </h1>
            <p className="mt-[22px] max-w-[46ch] text-[clamp(1.0625rem,1.35vw,1.1875rem)] leading-[1.62] text-ink-muted">
              Seven quick questions about your week. At the end you&rsquo;ll see which of five common stress patterns
              fits you best &mdash; and which app tools are built for it.
            </p>
            <button
              type="button"
              onClick={() => setPhase("questions")}
              className="group mt-[34px] inline-flex min-h-[48px] items-center gap-[9px] rounded-full border-[1.5px] border-ink/[0.22] px-[22px] text-[0.9375rem] font-semibold text-ink transition-[background-color,border-color] duration-200 hover:border-ink/40 hover:bg-ink/[0.055] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            >
              Start the quiz
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
            </button>
            <p className="mt-[18px] font-[family-name:var(--font-mono)] text-[0.6875rem] uppercase tracking-[0.12em] text-ink-muted">
              No account &middot; no email &middot; answers never leave this page
            </p>
          </section>
        )}

        {phase === "questions" && (
          <section>
            <button
              type="button"
              onClick={goBack}
              className="group inline-flex items-center gap-1.5 text-[0.875rem] font-semibold text-ink-muted transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            >
              <svg
                viewBox="0 0 24 24"
                width="16"
                height="16"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
                className="transition-transform duration-200 group-hover:-translate-x-[2px]"
              >
                <path d="M19.4 12H5M10.6 6.4 5 12l5.6 5.6" />
              </svg>
              Back
            </button>

            <div className="mt-5">
              <ProgressBar current={step + 1} total={QUIZ_QUESTIONS.length} />
            </div>

            <h2
              ref={promptRef}
              tabIndex={-1}
              className="mt-8 text-[clamp(1.55rem,4vw,2.125rem)] font-semibold leading-[1.12] tracking-[-0.024em] text-ink outline-none"
            >
              {QUIZ_QUESTIONS[step].prompt}
            </h2>

            <div className="mt-6 space-y-3">
              {QUIZ_QUESTIONS[step].options.map((option) => (
                <button
                  key={option.id}
                  type="button"
                  onClick={() => choose(QUIZ_QUESTIONS[step].id, option.id)}
                  aria-pressed={selected === option.id}
                  className={
                    "flex min-h-[56px] w-full items-center rounded-[18px] border px-5 py-3.5 text-left text-[1rem] font-medium leading-snug text-ink transition-[background-color,border-color] duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent " +
                    (selected === option.id ? "border-accent bg-tint" : "border-ink/[0.12] hover:border-ink/30 hover:bg-ink/[0.03]")
                  }
                >
                  {option.label}
                </button>
              ))}
            </div>
          </section>
        )}

        {phase === "computing" && (
          <div className="pt-[clamp(40px,9vw,88px)]" aria-live="polite">
            {/* BreathingRing doubles as the progress visual; its baked-in
                box-breathing captions don't apply here, so they're hidden and
                replaced by a status line. */}
            <div className="mx-auto w-[210px] max-w-full [&_p]:hidden">
              <BreathingRing />
            </div>
            <p className="mt-7 text-center text-[1.0625rem] font-semibold text-ink">Finding your pattern&hellip;</p>
          </div>
        )}

        {phase === "result" && result && <ResultCard result={result} onRestart={restart} />}
      </main>
    </div>
  );
}
