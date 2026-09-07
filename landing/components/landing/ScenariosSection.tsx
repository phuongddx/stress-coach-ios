// "When it actually helps", ported from sac-landing §11: three scenario cards
// with the design's small line-art vignettes (rising bars, watch ring, chat
// bubbles), each showing a moment the app earns its place.
import { SectionHeading } from "@/components/SectionHeading";

const SCENES = [
  {
    id: "late",
    when: "Working late",
    title: "Your score climbed while you weren't looking",
    copy: "You get a nudge before the evening is a write-off, with one two-minute reset that fits between two tabs.",
    art: (
      <svg viewBox="0 0 120 56" width="120" height="56" aria-hidden="true">
        <rect x="0" y="42" width="120" height="4" rx="2" fill="rgba(16,18,35,.08)" />
        <rect x="8" y="26" width="14" height="16" rx="4" fill="#00A000" opacity=".85" />
        <rect x="30" y="18" width="14" height="24" rx="4" fill="#007AFF" opacity=".85" />
        <rect x="52" y="10" width="14" height="32" rx="4" fill="#8A5A00" opacity=".85" />
        <rect x="74" y="4" width="14" height="38" rx="4" fill="#B25400" opacity=".9" />
        <rect x="96" y="14" width="14" height="28" rx="4" fill="#8A5A00" opacity=".85" />
      </svg>
    ),
  },
  {
    id: "glance",
    when: "A glance at your wrist",
    title: "You feel fine — the number disagrees",
    copy: "Strain shows up in HRV before it shows up in your mood. The complication catches it early enough to matter.",
    art: (
      <svg viewBox="0 0 120 56" width="120" height="56" aria-hidden="true">
        <rect x="44" y="4" width="32" height="48" rx="12" fill="rgba(16,18,35,.08)" />
        <circle cx="60" cy="28" r="13" fill="none" stroke="rgba(16,18,35,.12)" strokeWidth="4" pathLength={100} strokeDasharray="75 25" transform="rotate(135 60 28)" />
        <circle cx="60" cy="28" r="13" fill="none" stroke="#0288D1" strokeWidth="4" strokeLinecap="round" pathLength={100} strokeDasharray="30 70" transform="rotate(135 60 28)" />
        <path d="M16 28h14M90 28h14" stroke="rgba(16,18,35,.16)" strokeWidth="2.5" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    id: "rough-day",
    when: "A rough day",
    title: "You want to talk it through",
    copy: "The coach already has the context, so you can skip the setup and get to what would help right now.",
    art: (
      <svg viewBox="0 0 120 56" width="120" height="56" aria-hidden="true">
        <rect x="4" y="8" width="66" height="20" rx="9" fill="rgba(16,18,35,.08)" />
        <rect x="4" y="8" width="66" height="20" rx="9" fill="none" stroke="rgba(16,18,35,.06)" />
        <rect x="42" y="32" width="74" height="20" rx="9" fill="#101223" />
        <circle cx="16" cy="18" r="2.4" fill="rgba(16,18,35,.32)" />
        <circle cx="24" cy="18" r="2.4" fill="rgba(16,18,35,.32)" />
        <circle cx="32" cy="18" r="2.4" fill="rgba(16,18,35,.32)" />
        <path d="M54 42h50" stroke="rgba(255,255,255,.5)" strokeWidth="2.5" strokeLinecap="round" />
      </svg>
    ),
  },
] as const;

export function ScenariosSection() {
  return (
    <section className="bg-surface py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal>
          <SectionHeading eyebrow="In practice" title="When it actually helps" />
        </div>

        <ul role="list" data-reveal className="grid gap-[18px] min-[860px]:grid-cols-3">
          {SCENES.map((scene) => (
            <li
              key={scene.id}
              className="rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(24px,2.6vw,30px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]"
            >
              <div aria-hidden="true" className="mb-[18px]">
                {scene.art}
              </div>
              <span className="mb-[15px] block font-[family-name:var(--font-mono)] text-[0.625rem] uppercase tracking-[0.11em] text-accent-deep">
                {scene.when}
              </span>
              <h3 className="mb-[10px] text-[1.25rem] leading-[1.28] font-semibold tracking-[-0.02em] text-ink">{scene.title}</h3>
              <p className="text-[0.9375rem] leading-[1.56] text-ink-muted">{scene.copy}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
