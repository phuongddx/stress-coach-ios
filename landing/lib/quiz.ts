import { QUIZ_QUESTIONS, type PatternKey } from "@/content/quiz";

const ORDER: PatternKey[] = ["sleep", "overload", "overstim", "stagnation", "rhythm"];

export type AnswerMap = Record<string, string>;
export type QuizResult = {
  primary: PatternKey;
  secondary: PatternKey;
  scores: Record<PatternKey, number>;
  because: string[];
};

export function scoreQuiz(answers: AnswerMap): QuizResult {
  const scores = Object.fromEntries(ORDER.map(k => [k, 0])) as Record<PatternKey, number>;
  const because: string[] = [];
  for (const q of QUIZ_QUESTIONS) {
    const chosen = q.options.find(o => o.id === answers[q.id]);
    if (!chosen) throw new Error(`missing answer: ${q.id}`);
    for (const [k, w] of Object.entries(chosen.weights) as [PatternKey, number][]) scores[k] += w;
  }
  const ranked = [...ORDER].sort((a, b) => scores[b] - scores[a] || ORDER.indexOf(a) - ORDER.indexOf(b));
  const primary = ranked[0];
  const secondary = ranked[1];
  if (scores[primary] > 0) {
    for (const q of QUIZ_QUESTIONS) {
      const chosen = q.options.find(o => o.id === answers[q.id])!;
      if (chosen.weights[primary]) because.push(chosen.label);
    }
  }
  return { primary, secondary, scores, because };
}
