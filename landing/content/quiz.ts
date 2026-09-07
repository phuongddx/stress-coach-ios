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
