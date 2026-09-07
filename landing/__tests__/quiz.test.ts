import { describe, expect, it } from "vitest";
import { QUIZ_QUESTIONS, PATTERN_INFO } from "../content/quiz";
import { scoreQuiz } from "../lib/quiz";

// Hand-picked fixtures using option ids that actually exist in QUIZ_QUESTIONS.
// allSleep → sleep 10 (q1 2, q2 2, q3 2, q5 1, q6 1, q7 2), rhythm 2, overstim 1.
// allStagnation → stagnation 6 (q2 2, q4 2, q7 2), rhythm 1.
// tieFixture → sleep 2, overload 2, rhythm 1 — exact tie broken by fixed order.
const allSleep: Record<string, string> = {
  "q1-mornings": "sleep-opt",
  "q2-climb": "sleep-opt",
  "q3-sleep": "deep-sleep-opt",
  "q4-sitting": "neutral-opt",
  "q5-inputs": "screen-opt",
  "q6-routine": "deep-rhythm-opt",
  "q7-help": "sleep-opt",
};
const allStagnation: Record<string, string> = {
  "q1-mornings": "neutral-opt",
  "q2-climb": "stagnation-opt",
  "q3-sleep": "neutral-opt",
  "q4-sitting": "deep-stagnation-opt",
  "q5-inputs": "rhythm-opt",
  "q6-routine": "neutral-opt",
  "q7-help": "stagnation-opt",
};
const tieFixture: Record<string, string> = {
  "q1-mornings": "neutral-opt",
  "q2-climb": "sleep-opt",
  "q3-sleep": "neutral-opt",
  "q4-sitting": "neutral-opt",
  "q5-inputs": "rhythm-opt",
  "q6-routine": "neutral-opt",
  "q7-help": "overload-opt",
};

describe("scoreQuiz", () => {
  it("exposes exactly 7 questions with 4–5 options each and unique option ids per question", () => {
    expect(QUIZ_QUESTIONS).toHaveLength(7);
    for (const q of QUIZ_QUESTIONS) {
      expect(q.options.length).toBeGreaterThanOrEqual(4);
      expect(q.options.length).toBeLessThanOrEqual(5);
      expect(new Set(q.options.map(o => o.id)).size).toBe(q.options.length);
    }
  });
  it("all-sleep answers score Sleep Debt as primary", () => {
    expect(scoreQuiz(allSleep).primary).toBe("sleep");
  });
  it("all-stagnation answers score Stagnation as primary", () => {
    expect(scoreQuiz(allStagnation).primary).toBe("stagnation");
  });
  it("accumulates weights across questions and reports per-pattern scores", () => {
    const r = scoreQuiz(allSleep);
    expect(r.scores.sleep).toBe(10);
    expect(r.scores.rhythm).toBe(2);
    expect(Object.keys(r.scores)).toEqual(["sleep", "overload", "overstim", "stagnation", "rhythm"]);
  });
  it("breaks exact ties by fixed order sleep > overload > overstim > stagnation > rhythm", () => {
    const r = scoreQuiz(tieFixture);
    expect(r.scores.sleep).toBe(2);
    expect(r.scores.overload).toBe(2);
    expect(r.primary).toBe("sleep");
    expect(r.secondary).toBe("overload");
  });
  it("collects chosen-option texts tagged with the primary pattern into `because`", () => {
    const r = scoreQuiz(allSleep);
    expect(r.because.length).toBeGreaterThan(0);
    expect(r.because.every(t => typeof t === "string" && t.length > 3)).toBe(true);
  });
  it("throws on a missing answer", () => {
    expect(() => scoreQuiz({})).toThrow(/missing answer/);
  });
  it("PATTERN_INFO covers all five patterns with 3 coach-focus bullets and a mood face", () => {
    const keys = ["sleep", "overload", "overstim", "stagnation", "rhythm"] as const;
    for (const k of keys) {
      expect(PATTERN_INFO[k].coachFocus).toHaveLength(3);
      expect(PATTERN_INFO[k].moodFace).toMatch(/^mood-(relaxed|mild|moderate|high|severe)$/);
    }
  });
});
