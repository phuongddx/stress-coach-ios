import type { Metadata } from "next";

import { QuizFlow } from "@/components/funnel/QuizFlow";

export const metadata: Metadata = {
  title: "60-Second Stress Quiz",
  description:
    "Answer seven questions and find out what's driving your stress — and what your AI coach would focus on first.",
};
// Server wrapper: metadata above, client funnel below.

export default function Page() {
  return <QuizFlow />;
}
