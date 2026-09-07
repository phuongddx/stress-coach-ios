// FAQ content for the landing accordion (spec §4 item 13). Answers are the
// approved copy — edit here, not in the Faq component.
export type FaqEntry = { q: string; a: string };

export const FAQ_ENTRIES: FaqEntry[] = [
  {
    q: "Do I need an Apple Watch?",
    a: "No. Stress AI Coach scores your day from the health data your iPhone already collects. An Apple Watch adds real-time readings, complications, and a watch app.",
  },
  {
    q: "What data leaves my device?",
    a: "Stress scoring happens on your device. If you use the AI coach, only derived scores and trends are used to give you relevant guidance — never your raw health data — and health sync is optional and revocable.",
  },
  {
    q: "Is this medical advice?",
    a: "No. Stress AI Coach is a wellness tool. It doesn't diagnose or treat anything, and it's no substitute for a qualified healthcare provider.",
  },
  {
    q: "What does Premium unlock?",
    a: "Unlimited AI coaching, all calm tools, full trend history, and the full watch and widget experience. The free tier includes your daily score and basic trends.",
  },
  {
    q: "How does the score work?",
    a: "A 0–100 score from five factors — heart rate variability, heart rate, sleep, activity, and recovery — each with its own weight, plus a confidence reading and factor breakdown.",
  },
  {
    q: "Can I revoke Health access?",
    a: "Anytime, in iOS Settings → Privacy & Security → Health. The app keeps working with manual entries.",
  },
  {
    q: "What languages are available?",
    a: "English at launch, with more planned.",
  },
];
