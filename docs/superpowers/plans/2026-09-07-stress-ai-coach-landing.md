# Stress AI Coach Marketing Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved marketing site — a Next.js landing page (14 sections, ported from the Open Design `sac-landing.html` canonical design) plus a `/start` stress-pattern quiz funnel ending at the App Store CTA.

**Architecture:** New self-contained `landing/` Next.js App Router project inside this repo, deployed as its own Vercel project. Pure prerendered marketing surface: no backend, no analytics, no auth. All visuals are authored SVG React components (no screenshots). The quiz is a client-side flow driven by a pure TypeScript scoring engine that is unit-tested.

**Tech Stack:** Next.js 15 (App Router), TypeScript, Tailwind CSS v4 (`@tailwindcss/postcss`), Roboto via `next/font/google` (400/500/700), Vitest for the quiz engine tests.

**Spec:** `docs/superpowers/specs/2026-09-07-stress-ai-coach-landing-design.md` (approved, commit `7aeaa85`).

**Canonical design source:** `sac-landing.html` in the Open Design project at
`~/Library/Application Support/Open Design/namespaces/release-stable/data/projects/2358d73c-28a4-4f2c-b005-27515b820998/sac-landing.html`
(+ `screenshots/sac-landing-1440.png` / `-390.png` captures, and `assets/images/stress-ai-coach/*.svg`). **Read that file before any UI task.** It is the design contract: tokens (its `:root` block, copied verbatim into Task 1), compositions, copy tone, motion vocabulary. Where this plan and `sac-landing.html` disagree visually, the HTML wins.

## Global Constraints

- Do NOT touch anything outside `landing/` and this plan's docs — no Xcode project edits, no backend edits, no `docs-site/` edits.
- Repo rule note: this work runs under the user's explicit superpowers flow (brainstorming → writing-plans), which the user invoked directly; the GSD-command gate is satisfied by that instruction.
- Palette verbatim: ink `#101223`, muted `#6B6E7B`, accent `#0288D1`, accent-bright `#4FC3F7`, ripple-tint `#E1F2FC`, surface `#F2F2F7`, warm surface `#FFFDF6`, tiers `#00A000/#007AFF/#8A5A00/#B25400/#FF3B30`, gradient `#4FC3F7→#0288D1→#10B981`.
- Type: Roboto only (400/500/700), `next/font/google`, `--font-roboto` variable; mono `ui-monospace, "SF Mono", Menlo, monospace` for tiny labels only.
- **No app screenshots anywhere.** All visuals authored SVG/illustration.
- **No fabricated social proof:** no testimonials, user counts, review scores, "featured in" claims, countdowns, scarcity. Trust facts only (§4 of spec).
- Every App Store CTA links to `siteConfig.appStoreUrl` — never a hardcoded URL.
- Legal links: `https://stressmonitor-docs.vercel.app/legal/privacy` and `/legal/terms`. Support: `support@stressmonitor.app`.
- All motion gated by `prefers-reduced-motion`.
- Responsive 390px → 1440px, no horizontal scroll.
- Commit after every task; conventional commits (`feat(landing): …`, `test(quiz): …`).

## File Structure

```
landing/
├── package.json                 # next, react, tailwind v4, vitest
├── next.config.ts               # typedRoutes on; nothing else
├── tsconfig.json                # bundler mode, @/* → ./*
├── postcss.config.mjs           # @tailwindcss/postcss
├── site.config.ts               # single source of outbound URLs/copy facts
├── app/
│   ├── layout.tsx               # Roboto font, metadata defaults, JSON-LD
│   ├── page.tsx                 # assembles the 14 landing sections
│   ├── globals.css              # tokens + tailwind import + shared keyframes
│   ├── sitemap.ts / robots.ts
│   └── start/page.tsx           # /start funnel (client)
├── components/
│   ├── AppStoreBadge.tsx        # black badge (inline SVG)
│   ├── SectionHeading.tsx
│   ├── MoodTierStrip.tsx        # 5 tier chips
│   ├── illustrations/
│   │   ├── RippleMark.tsx  ScoreDial.tsx  TrendWave.tsx  ChatVignette.tsx
│   │   ├── BreathingRing.tsx  WatchGlyph.tsx  CharacterRow.tsx
│   └── landing/                 # one file per section, S1…S14
│       ├── Nav.tsx Hero.tsx TrustStrip.tsx ScoreSection.tsx CoachSection.tsx
│       ├── RippleSection.tsx CalmSection.tsx PatternsSection.tsx WatchSection.tsx
│       └── PrivacySection.tsx ScenariosSection.tsx PricingTable.tsx Faq.tsx FinalCta.tsx Footer.tsx
├── content/
│   ├── quiz.ts                  # questions + weights + pattern info (data only)
│   └── faq.ts                   # FAQ entries
├── lib/quiz.ts                  # pure scoring engine
└── __tests__/quiz.test.ts       # Vitest unit tests
```

---

### Task 1: Scaffold — config, tokens, fonts, empty routes

**Files:**
- Create: everything under `landing/` except section components (`package.json`, configs, `site.config.ts`, `app/layout.tsx`, `app/page.tsx` stub, `app/start/page.tsx` stub, `app/globals.css`, `app/sitemap.ts`, `app/robots.ts`, `postcss.config.mjs`, `tsconfig.json`)

**Interfaces:**
- Produces: `siteConfig` object (exact shape below) consumed by every CTA-bearing component; CSS custom properties on `:root` consumed by all components.

- [ ] **Step 1: Scaffold the project**

```bash
mkdir -p landing && cd landing
npm init -y >/dev/null
npm install next@15 react react-dom
npm install -D typescript @types/node @types/react @types/react-dom tailwindcss @tailwindcss/postcss postcss vitest
```

`landing/package.json` scripts:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "test": "vitest run",
    "lint": "next lint"
  }
}
```

- [ ] **Step 2: `landing/site.config.ts`**

```ts
export const siteConfig = {
  name: "Stress AI Coach",
  tagline: "Understand your stress. Do something about it.",
  appStoreUrl: "https://apps.apple.com/app/stress-ai-coach/idXXXXXXXXX", // placeholder until ASC app ID exists — single source for every CTA
  supportEmail: "support@stressmonitor.app",
  docsBaseUrl: "https://stressmonitor-docs.vercel.app",
  privacyUrl: "https://stressmonitor-docs.vercel.app/legal/privacy",
  termsUrl: "https://stressmonitor-docs.vercel.app/legal/terms",
  quizPath: "/start",
} as const;
```

- [ ] **Step 3: `landing/app/globals.css`** — tokens verbatim from `sac-landing.html` `:root`, Tailwind v4 wiring

```css
@import "tailwindcss";

:root {
  --ink: #101223;
  --ink-muted: #6b6e7b;
  --accent: #0288d1;
  --accent-bright: #4fc3f7;
  --tint: #e1f2fc;
  --surface: #f2f2f7;
  --surface-warm: #fffdf6;
  --tier-relaxed: #00a000;
  --tier-mild: #007aff;
  --tier-moderate: #8a5a00;
  --tier-high: #b25400;
  --tier-severe: #ff3b30;
  --grad-a: #4fc3f7;
  --grad-b: #0288d1;
  --grad-c: #10b981;
  --font-mono: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
}

@theme inline {
  --color-ink: var(--ink);
  --color-ink-muted: var(--ink-muted);
  --color-accent: var(--accent);
  --color-accent-bright: var(--accent-bright);
  --color-tint: var(--tint);
  --color-surface: var(--surface);
  --color-surface-warm: var(--surface-warm);
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```

- [ ] **Step 4: `landing/app/layout.tsx`** — Roboto via next/font, base metadata

```tsx
import type { Metadata } from "next";
import { Roboto } from "next/font/google";
import { siteConfig } from "@/site.config";
import "./globals.css";

const roboto = Roboto({ weight: ["400", "500", "700"], subsets: ["latin"], variable: "--font-roboto", display: "swap" });

export const metadata: Metadata = {
  title: { default: `${siteConfig.name} — ${siteConfig.tagline}`, template: `%s · ${siteConfig.name}` },
  description: "Stress AI Coach turns the health data your iPhone already collects into a daily 0–100 stress score, then helps you act on it with an AI wellness coach and calm tools. iPhone + Apple Watch.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={roboto.variable}>
      <body className="font-[family-name:var(--font-roboto)] text-ink bg-white antialiased">{children}</body>
    </html>
  );
}
```

`landing/next.config.ts`: `const nextConfig: NextConfig = { typedRoutes: true }; export default nextConfig;`
`landing/postcss.config.mjs`: `export default { plugins: { "@tailwindcss/postcss": {} } };`
`landing/tsconfig.json`: standard Next 15 TS config with `"paths": { "@/*": ["./*"] }`, `"moduleResolution": "bundler"`, `"jsx": "preserve"`, includes `next-env.d.ts`, `.next/types`, `**/*.ts`, `**/*.tsx`.
Stub pages: `app/page.tsx` and `app/start/page.tsx` each `export default function Page() { return <main />; }`.
`app/sitemap.ts`: `export default function sitemap() { return [{ url: "https://PLACEHOLDER.vercel.app/", lastModified: new Date() }]; }` (domain updated at deploy).
`app/robots.ts`: allow all, sitemap reference.

- [ ] **Step 5: Verify build**

Run: `cd landing && npm run build`
Expected: clean production build, both routes prerendered (`/` and `/start` in output list).

- [ ] **Step 6: Commit**

```bash
git add landing
git commit -m "feat(landing): scaffold Next.js site — config, tokens, Roboto, routes"
```

---

### Task 2: Quiz content + scoring engine (TDD)

**Files:**
- Create: `landing/content/quiz.ts`, `landing/lib/quiz.ts`
- Test: `landing/__tests__/quiz.test.ts`

**Interfaces:**
- Produces: `type PatternKey = "sleep" | "overload" | "overstim" | "stagnation" | "rhythm"`; `QUIZ_QUESTIONS: QuizQuestion[]`; `PATTERN_INFO: Record<PatternKey, PatternInfo>` (both from `content/quiz.ts`); `scoreQuiz(answers: AnswerMap): QuizResult` where `AnswerMap = Record<string, string>` (questionId → optionId) and `QuizResult = { primary: PatternKey; secondary: PatternKey; scores: Record<PatternKey, number>; because: string[] }`. Throws `Error("missing answer: <questionId>")` on incomplete input.

- [ ] **Step 1: Write the failing tests** — `landing/__tests__/quiz.test.ts`

```ts
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd landing && npx vitest run`
Expected: FAIL — `Cannot find module '../content/quiz'`.

- [ ] **Step 3: Write `landing/content/quiz.ts`** (data only — questions, weights, pattern info)

```ts
export type PatternKey = "sleep" | "overload" | "overstim" | "stagnation" | "rhythm";

export type QuizOption = {
  id: string;
  label: string;
  weights: Partial<Record<PatternKey, number>>;
};
export type QuizQuestion = {
  id: string;
  prompt: string;
  options: QuizOption[];
};
export type PatternInfo = {
  key: PatternKey;
  name: string;
  moodFace: string; // asset name in assets/images/stress-ai-coach/
  summary: string;
  coachFocus: [string, string, string];
};

export const QUIZ_QUESTIONS: QuizQuestion[] = [
  {
    id: "q1-mornings",
    prompt: "How are your mornings?",
    options: [
      { id: "neutral-opt", label: "I usually wake up feeling fine", weights: {} },
      { id: "sleep-opt", label: "Groggy for the first hour, no matter what", weights: { sleep: 2 } },
      { id: "rhythm-opt", label: "It depends wildly on the day", weights: { rhythm: 2 } },
      { id: "overload-opt", label: "I wake up already thinking about work", weights: { overload: 2 } },
    ],
  },
  {
    id: "q2-climb",
    prompt: "When your stress climbs, what's usually happening?",
    options: [
      { id: "overload-opt", label: "Work follows me home", weights: { overload: 2 } },
      { id: "overstim-opt", label: "Too much noise, news, notifications", weights: { overstim: 2 } },
      { id: "sleep-opt", label: "I'm running on too little sleep", weights: { sleep: 2 } },
      { id: "both-opt", label: "Everything at once — I can't point at one", weights: { overload: 1, overstim: 1 } },
      { id: "stagnation-opt", label: "I've been sitting still for days", weights: { stagnation: 2 } },
    ],
  },
  {
    id: "q3-sleep",
    prompt: "How much sleep did you get this week?",
    options: [
      { id: "neutral-opt", label: "7+ hours most nights", weights: {} },
      { id: "sleep-opt", label: "6–7 hours, dragging by Friday", weights: { sleep: 1 } },
      { id: "deep-sleep-opt", label: "Under 6 most nights", weights: { sleep: 2 } },
      { id: "rhythm-opt", label: "No idea — it varies a lot", weights: { rhythm: 2 } },
    ],
  },
  {
    id: "q4-sitting",
    prompt: "How much of your day is spent sitting?",
    options: [
      { id: "neutral-opt", label: "I move every hour or so", weights: {} },
      { id: "stagnation-opt", label: "Long stretches, but I do exercise", weights: { stagnation: 1 } },
      { id: "deep-stagnation-opt", label: "Almost all of it, every day", weights: { stagnation: 2 } },
      { id: "rhythm-opt", label: "Depends entirely on the week", weights: { rhythm: 1 } },
    ],
  },
  {
    id: "q5-inputs",
    prompt: "Pick your biggest daily input.",
    options: [
      { id: "overstim-opt", label: "Coffee — more than two cups", weights: { overstim: 2 } },
      { id: "screen-opt", label: "Screens until the moment I sleep", weights: { overstim: 1, sleep: 1 } },
      { id: "overload-opt", label: "A back-to-back calendar", weights: { overload: 2 } },
      { id: "rhythm-opt", label: "None of these feel like mine", weights: { rhythm: 1 } },
    ],
  },
  {
    id: "q6-routine",
    prompt: "How regular is your routine?",
    options: [
      { id: "neutral-opt", label: "Meals, sleep, movement — pretty consistent", weights: {} },
      { id: "rhythm-opt", label: "Weekdays yes, weekends collapse", weights: { rhythm: 2 } },
      { id: "deep-rhythm-opt", label: "Every day is different", weights: { rhythm: 2, sleep: 1 } },
      { id: "stagnation-opt", label: "Routine? I barely leave the desk", weights: { stagnation: 1 } },
    ],
  },
  {
    id: "q7-help",
    prompt: "What would help most right now?",
    options: [
      { id: "overload-opt", label: "Knowing when to stop", weights: { overload: 2 } },
      { id: "sleep-opt", label: "Actually sleeping well", weights: { sleep: 2 } },
      { id: "overstim-opt", label: "Quieting my head", weights: { overstim: 2 } },
      { id: "stagnation-opt", label: "Getting my body moving", weights: { stagnation: 2 } },
      { id: "rhythm-opt", label: "A rhythm I can actually keep", weights: { rhythm: 2 } },
    ],
  },
];

export const PATTERN_INFO: Record<PatternKey, PatternInfo> = {
  sleep: {
    key: "sleep", name: "Sleep Debt", moodFace: "mood-moderate",
    summary: "Your answers point at recovery first: tired mornings, short nights, and a body running behind on rest.",
    coachFocus: [
      "Tracks the sleep factor in your daily score and 7-day trend",
      "Wind-down nudges when your score climbs late",
      "Morning readiness so you can see recovery return",
    ],
  },
  overload: {
    key: "overload", name: "Overload", moodFace: "mood-high",
    summary: "Your stress looks like an always-on stack: work that follows you home and a mind that doesn't clock out.",
    coachFocus: [
      "High-stress alerts the moment your score spikes",
      "In-the-moment resets — 60-second breathing, a mini walk",
      "Weekly pattern view of when overload hits hardest",
    ],
  },
  overstim: {
    key: "overstim", name: "Overstimulation", moodFace: "mood-mild",
    summary: "Caffeine, screens, and a noisy feed are keeping your nervous system from settling.",
    coachFocus: [
      "Stimulus check-ins tied to your daily score",
      "Breathing resets (box, 4-7-8, body scan) built for busy days",
      "Trends that show which days your inputs pile up",
    ],
  },
  stagnation: {
    key: "stagnation", name: "Stagnation", moodFace: "mood-moderate",
    summary: "Long stretches of stillness are weighing on your score — your body is asking for movement.",
    coachFocus: [
      "Activity factor visible in every daily reading",
      "Mini-walk resets you can do in minutes",
      "Movement patterns across your week",
    ],
  },
  rhythm: {
    key: "rhythm", name: "Irregular Rhythm", moodFace: "mood-mild",
    summary: "Your days don't repeat — sleep, meals, and movement shift so much your body never settles into a baseline.",
    coachFocus: [
      "Daily rhythm patterns and a weekly calendar view",
      "Gentle consistency nudges, not rigid schedules",
      "Trends that reveal your best-rhythm weeks",
    ],
  },
};
```

- [ ] **Step 4: Write `landing/lib/quiz.ts`**

```ts
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd landing && npx vitest run`
Expected: PASS, all 8 tests.

- [ ] **Step 6: Commit**

```bash
git add landing/content landing/lib landing/__tests__
git commit -m "feat(quiz): stress-pattern questions and scoring engine (5 patterns, tie-break, because-list)"
```

---

### Task 3: Shared components + illustrations

**Files:**
- Create: `landing/components/AppStoreBadge.tsx`, `landing/components/SectionHeading.tsx`, `landing/components/MoodTierStrip.tsx`, `landing/components/illustrations/RippleMark.tsx`, `ScoreDial.tsx`, `TrendWave.tsx`, `ChatVignette.tsx`, `BreathingRing.tsx`, `WatchGlyph.tsx`, `CharacterRow.tsx`

**Interfaces:**
- Consumes: CSS token variables from Task 1.
- Produces (exact props): `AppStoreBadge({ className?: string })` renders `<a href={siteConfig.appStoreUrl}>` with black-badge inline SVG; `SectionHeading({ eyebrow?: string; title: string; lede?: string })`; `MoodTierStrip()` — 5 chips labeled Relaxed/Mild/Elevated/High/Severe in the five tier colors; `RippleMark({ size?: number })`; `ScoreDial({ score: number; tier?: "relaxed"|"mild"|"moderate"|"high"|"severe" })` — SVG arc dial, tier color, big number; `TrendWave({ points?: number[] })` — smooth line chart in tier colors; `ChatVignette()` — static 3-bubble coach conversation (designed, not screenshot); `BreathingRing({ label?: string })` — CSS-animated expanding ring (4-4-4-4 box cadence, 8s loop); `WatchGlyph({ score?: number })` — abstract rounded-rect watch with complication dots; `CharacterRow()` — 5 character cards using inline copies of the character SVG paths from `assets/images/stress-ai-coach/{ripple,blossom,ember,lumi,zephyr}.svg`.

- [ ] **Step 1: Implement the components.** Port each visual from the matching block of `sac-landing.html` (read it first — it is the design contract): the hero dial → `ScoreDial`, §"See your patterns" chart → `TrendWave`, §coach chat → `ChatVignette`, §calm ring → `BreathingRing`, §watch band → `WatchGlyph`, §"Meet Ripple" → `CharacterRow`. Copy the SVG geometry/colors from that file; convert to typed React components with the props above. Character SVG art: copy the `<ellipse>/<circle>/<path>` groups verbatim from the Open Design `assets/images/stress-ai-coach/*.svg` files into `CharacterRow.tsx` as JSX.
- [ ] **Step 2: Verify build** — Run: `cd landing && npm run build`. Expected: clean.
- [ ] **Step 3: Commit** — `git add landing/components && git commit -m "feat(landing): shared components and SVG illustrations (ported from sac-landing design)"`

---

### Task 4: Landing sections S1–S7

**Files:**
- Create: `landing/components/landing/Nav.tsx`, `Hero.tsx`, `TrustStrip.tsx`, `ScoreSection.tsx`, `CoachSection.tsx`, `RippleSection.tsx`, `CalmSection.tsx`
- Modify: `landing/app/page.tsx` (assemble S1–S7; S8–S14 land in Task 5)

**Interfaces:**
- Consumes: Task 3 components, `siteConfig`.
- Produces: one exported component per file, same name as file. `Nav` is sticky with anchors `#score #coach #ripple #calm #faq` and the `AppStoreBadge` pill; `Hero` includes the `/start` link ("Take the 60-second stress quiz →") and the white→`var(--tint)` background transition on load (CSS animation, ~1s, respects reduced-motion).

- [ ] **Step 1: Implement the seven sections** — copy, composition, and tone ported section-by-section from `sac-landing.html` (headings there: "Your stress, scored", "A coach that knows your context", "Meet Ripple", "Calm in minutes, not courses"). Constraints that override the source file: remove any "CONFIDENCE · HIGH"-style sublabel from the dial (already removed there), keep honest trust copy — `Built on Apple Health · Scores on your device · iPhone + Apple Watch`.
- [ ] **Step 2: Assemble** in `app/page.tsx` as `<Nav/><Hero/><TrustStrip/><ScoreSection/><CoachSection/><RippleSection/><CalmSection/>` inside a `<main>`; section wrappers get `id` anchors.
- [ ] **Step 3: Verify** — Run: `cd landing && npm run build && npm run dev` (background), then in a browser at `http://localhost:3000`: assert headings for S2/S4/S5/S6/S7 exist, hero shows both CTAs (`a[href$="idXXXXXXXXX"]` count ≥1, `a[href="/start"]` count ≥1), and no horizontal scrollbar at 390px and 1440px viewports.
- [ ] **Step 4: Commit** — `git add landing && git commit -m "feat(landing): sections S1–S7 (nav, hero, trust, score, coach, ripple, calm)"`

---

### Task 5: Landing sections S8–S14 + FAQ content + page complete

**Files:**
- Create: `landing/components/landing/PatternsSection.tsx`, `WatchSection.tsx`, `PrivacySection.tsx`, `ScenariosSection.tsx`, `PricingTable.tsx`, `Faq.tsx`, `FinalCta.tsx`, `Footer.tsx`; `landing/content/faq.ts`
- Modify: `landing/app/page.tsx`

**Interfaces:**
- Consumes: Task 3 components, `siteConfig`, `siteConfig.privacyUrl/termsUrl/docsBaseUrl/supportEmail`.
- Produces: completed `/` page. `Faq` renders an accordion from `content/faq.ts` (`type FaqEntry = { q: string; a: string }`, export `FAQ_ENTRIES: FaqEntry[]`) using native `<details>` elements (no JS).

- [ ] **Step 1: Write `content/faq.ts`** with these 7 entries (answers 1–2 sentences each, from the spec):
  1. "Do I need an Apple Watch?" — "No. Stress AI Coach scores your day from the health data your iPhone already collects. An Apple Watch adds real-time readings, complications, and a watch app."
  2. "What data leaves my device?" — "Stress scoring happens on your device. If you use the AI coach, only derived scores and trends are used to give you relevant guidance — never your raw health data — and health sync is optional and revocable."
  3. "Is this medical advice?" — "No. Stress AI Coach is a wellness tool. It doesn't diagnose or treat anything, and it's no substitute for a qualified healthcare provider."
  4. "What does Premium unlock?" — "Unlimited AI coaching, all calm tools, full trend history, and the full watch and widget experience. The free tier includes your daily score and basic trends."
  5. "How does the score work?" — "A 0–100 score from five factors — heart rate variability, heart rate, sleep, activity, and recovery — each with its own weight, plus a confidence reading and factor breakdown."
  6. "Can I revoke Health access?" — "Anytime, in iOS Settings → Privacy & Security → Health. The app keeps working with manual entries."
  7. "What languages are available?" — "English at launch, with more planned."
- [ ] **Step 2: Implement the seven sections** — headings per spec §4 items 8–14 (source: `sac-landing.html` sections "See your patterns", "At a glance, all day", "Privacy first, by architecture", "When it actually helps", "Free vs Premium", "Before you download", closing CTA + footer). `PricingTable` feature split verbatim from spec §4 item 12. Footer carries the "not medical advice" line: `Stress AI Coach is a wellness tool — not a medical device, and not a substitute for professional care.`
- [ ] **Step 3: Assemble + verify** — full `/` renders S1–S14; browser check: FAQ accordion opens (`details[open]` toggles), footer legal links point at `siteConfig.privacyUrl/termsUrl`, all App Store CTAs share one href, no horizontal scroll at 390/1440.
- [ ] **Step 4: Commit** — `git add landing && git commit -m "feat(landing): sections S8–S14 + FAQ content — landing page complete"`

---

### Task 6: `/start` quiz funnel

**Files:**
- Create: `landing/components/funnel/QuizFlow.tsx`, `ProgressBar.tsx`, `ResultCard.tsx`
- Modify: `landing/app/start/page.tsx`

**Interfaces:**
- Consumes: `QUIZ_QUESTIONS`, `PATTERN_INFO`, `scoreQuiz` (Task 2 — exact signatures there), `AppStoreBadge`, mood-face SVGs (inline the five `mood-*.svg` as React components inside `ResultCard.tsx`).
- Produces: `/start` page = `"use client"` `QuizFlow` with states `intro → step(0…6) → computing → result`; `ProgressBar({ current: number; total: number })`; `ResultCard({ result: QuizResult; onRestart: () => void })` showing `PATTERN_INFO[result.primary]` (name, moodFace, summary, coachFocus bullets, `result.because` as "your answers point here" list) + `AppStoreBadge` ("Start with this plan") + secondary link "See how the score works" → `/#score`.

- [ ] **Step 1: Implement the flow.** One question per screen (options as full-width tappable cards, min-height 56px); auto-advance 150ms after selection; "3 of 7" progress; back arrow; `computing` state shows `BreathingRing` pulse for ~1.2s then `scoreQuiz(answers)`; restart button on result clears state. No localStorage, no network.
- [ ] **Step 2: Verify in browser** — dev server at `/start`: click through selecting every first option; assert result card shows `PATTERN_INFO` name for the expected pattern (per `content/quiz.ts`, first options are q1 neutral, q2 overload-opt, q3 neutral, q4 neutral, q5 overstim-opt, q6 neutral, q7 overload-opt → scores: overload 4, overstim 2, sleep/stagnation/rhythm 0 → primary "overload", secondary "overstim"); restart returns to intro; progress shows "7 of 7" before result.
- [ ] **Step 3: Verify build** — `cd landing && npm run build`. Expected: clean.
- [ ] **Step 4: Commit** — `git add landing && git commit -m "feat(funnel): /start stress-pattern quiz — 7 steps, scoring, result card, App Store CTA"`

---

### Task 7: SEO + final QA + README

**Files:**
- Modify: `landing/app/layout.tsx` (JSON-LD), `landing/app/page.tsx` + `app/start/page.tsx` (route metadata), Create: `landing/README.md`

- [ ] **Step 1: Metadata + JSON-LD.** `app/start/page.tsx`: `export const metadata = { title: "60-Second Stress Quiz", description: "Answer seven questions and find out what's driving your stress — and what your AI coach would focus on first." }` (page must stay a server component wrapper around the client `QuizFlow`). `layout.tsx`: `<script type="application/ld+json">` with `SoftwareApplication` (name, applicationCategory "Health & Fitness", operatingSystem "iOS 18.6+, watchOS 11.6+", offers price "0"). Add `public/og.png` (1200×630 — export the hero region of `screenshots/sac-landing-1440.png` as a crop) and reference it in metadata `openGraph.images`.
- [ ] **Step 2: QA pass.** Browser both viewports: `/` and `/start`; emulate `prefers-reduced-motion: reduce` and confirm all content visible without animation; check `view-source` contains JSON-LD; `curl localhost:3000/sitemap.xml` and `/robots.txt` return 200.
- [ ] **Step 3: `landing/README.md`** — how to run (`npm install`, `npm run dev`), build, test; the single-place-to-edit list (`site.config.ts` appStoreUrl; domain in `sitemap.ts` at deploy); deploy note: Vercel → New Project → root directory `landing/`.
- [ ] **Step 4: Full verification** — `cd landing && npm run build && npm run test`. Expected: both clean.
- [ ] **Step 5: Commit** — `git add landing && git commit -m "feat(landing): SEO (metadata, JSON-LD, sitemap, OG) + QA + README"`

---

## Self-Review (done during planning)

1. **Spec coverage:** §3 IA → Task 1; §4 sections 1–14 → Tasks 4–5; §5 funnel (incl. explicit-outs: no countdown/email/paywall anywhere in the component specs) → Task 6; §6 tokens/type/motion/illustration-rule → Tasks 1/3 + Global Constraints; §7 tech incl. SEO/OG/sitemap/JSON-LD → Tasks 1/7; §8 integrity → Global Constraints + FAQ/PricingTable copy; §9 verification → per-task browser checks + Task 7 QA (Lighthouse ≥95 noted as target; final measurement at deploy when domain exists).
2. **Placeholders:** the `idXXXXXXXXX` App Store URL is the spec's intentional config placeholder; no TBDs in tasks.
3. **Type consistency:** `PatternKey`/`QuizResult`/`scoreQuiz`/`AnswerMap` identical in Tasks 2 and 6; `siteConfig` fields used in Tasks 1/4/5/6/7 all defined in Task 1.
