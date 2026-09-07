// "Calm in minutes, not courses", ported from sac-landing §7: the seven-tool
// grid and the breathing demo card (Task 3's pure-CSS BreathingRing). The
// design's Start/pause button is not rendered — the static server component
// can't drive phases (decision documented on BreathingRing itself).
import type { ReactNode } from "react";
import { BreathingRing } from "@/components/illustrations/BreathingRing";
import { SectionHeading } from "@/components/SectionHeading";

function ToolIcon({ paths }: { paths: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="24"
      height="24"
      fill="none"
      stroke="var(--accent)"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className="mt-[2px] flex-none"
    >
      {paths}
    </svg>
  );
}

const ICONS = {
  box: <><rect x="4.4" y="4.4" width="15.2" height="15.2" rx="3" /><path d="M4.4 12h15.2M12 4.4v15.2" /></>,
  "478": <><circle cx="12" cy="12" r="3" /><path d="M12 5.4a6.6 6.6 0 0 1 6.6 6.6" /><path d="M12 2.2a9.8 9.8 0 0 1 9.8 9.8" /></>,
  scan: <><circle cx="12" cy="5.2" r="2.4" /><path d="M12 7.6v6.2M8.6 21l3.4-7.2L15.4 21M8.4 11h7.2" /><path d="M3.4 16.4h17.2" /></>,
  walk: <><path d="M7.6 3.6c1.4 0 2.2 1.4 2.2 3.4s-.6 3.6-2 3.6-2.4-1.6-2.4-3.6.8-3.4 2.2-3.4Z" /><path d="M5.4 12.8c1.6-.6 3.2-.4 4.4.4" /><path d="M16.4 10.2c1.4 0 2.2 1.4 2.2 3.4s-.6 3.6-2 3.6-2.4-1.6-2.4-3.6.8-3.4 2.2-3.4Z" /><path d="M14.2 19.4c1.6-.6 3.2-.4 4.4.4" /></>,
  splash: <><path d="M12 3.2c3.2 4 5.4 6.6 5.4 9.4A5.4 5.4 0 0 1 6.6 12.6c0-2.8 2.2-5.4 5.4-9.4Z" /><path d="M9.6 13.4a2.6 2.6 0 0 0 2.6 2.6" /></>,
  journal: <><path d="M4.4 4.6A2.2 2.2 0 0 1 6.6 2.4h11a1 1 0 0 1 1 1v17.2H6.6a2.2 2.2 0 0 1-2.2-2.2Z" /><path d="M4.4 17.4h14.2" /><path d="M9 7.6h5.4" /></>,
  mood: <><circle cx="12" cy="12" r="9" /><path d="M9 15s1.2 1.4 3 1.4S15 15 15 15" /><circle cx="9.2" cy="10" r=".9" fill="var(--accent)" stroke="none" /><circle cx="14.8" cy="10" r=".9" fill="var(--accent)" stroke="none" /></>,
} as const;

const TOOLS = [
  { id: "box", name: "Box breathing", copy: "Four counts in, hold, out, hold. The reliable one." },
  { id: "478", name: "4-7-8 breathing", copy: "A longer exhale for when you need to come down fast." },
  { id: "scan", name: "Body scan", copy: "Head to feet, noticing where you're holding tension." },
  { id: "walk", name: "Mini walks", copy: "Five minutes outside, logged as a real reset." },
  { id: "splash", name: "Cold splash", copy: "Cold water on the face — the fastest tool here." },
  { id: "journal", name: "Gratitude journal", copy: "A few lines to close the loop on the day." },
  { id: "mood", name: "Mood check-ins", copy: "Tell the app how you actually feel, so the score has your side of the story too." },
] as const;

export function CalmSection() {
  return (
    <section id="calm" className="py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal>
          <SectionHeading
            eyebrow="The tools"
            title="Calm in minutes, not courses"
            lede="Short, finishable resets you can run mid-meeting or mid-walk. The coach suggests one; you can always pick your own."
          />
        </div>

        <div className="mt-[clamp(38px,4.4vw,60px)] grid items-start gap-[clamp(26px,3.4vw,42px)] min-[940px]:grid-cols-[minmax(0,1fr)_minmax(0,0.82fr)]">
          <ul role="list" data-reveal className="grid gap-[14px] grid-cols-1 min-[520px]:grid-cols-2">
            {TOOLS.map((tool) => (
              <li
                key={tool.id}
                className="flex items-start gap-3.5 rounded-[18px] border border-ink/[0.06] bg-white px-5 py-[19px] transition-[border-color,transform,box-shadow] duration-200 hover:-translate-y-0.5 hover:border-accent/30 hover:shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)] last:min-[520px]:col-span-full"
              >
                <ToolIcon paths={ICONS[tool.id]} />
                <div>
                  <h3 className="mb-1 text-[0.9375rem] font-semibold text-ink">{tool.name}</h3>
                  <p className="text-[0.8125rem] leading-[1.45] text-ink-muted">{tool.copy}</p>
                </div>
              </li>
            ))}
          </ul>

          <div
            data-reveal
            className="rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(26px,3vw,34px)] text-center shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)] min-[940px]:sticky min-[940px]:top-24"
          >
            <p className="mb-3 flex items-center justify-center gap-2.5 font-[family-name:var(--font-mono)] text-[0.6875rem] uppercase tracking-[0.15em] text-accent-deep">
              <span
                aria-hidden="true"
                className="h-0.5 w-[22px] shrink-0 rounded-full bg-[linear-gradient(120deg,var(--grad-a)_0%,var(--grad-b)_55%,var(--grad-c)_100%)]"
              />
              Try it now
            </p>
            <BreathingRing label="Box breathing" />
          </div>
        </div>
      </div>
    </section>
  );
}
