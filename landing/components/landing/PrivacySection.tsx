// "Privacy first, by architecture", ported from sac-landing §10: three check
// cards on the plain white band.
import { SectionHeading } from "@/components/SectionHeading";

const CHECKS = [
  {
    id: "on-device",
    title: "Scoring happens on-device",
    copy: "Your stress score is computed on your iPhone from your own health data. The scoring itself never needs a server.",
  },
  {
    id: "derived-only",
    title: "The coach sees scores, not records",
    copy: "When you chat, the coach receives derived scores and trends — never your raw health data.",
  },
  {
    id: "consent",
    title: "Consent-gated and revocable",
    copy: "Health sync is optional and off until you allow it. Turn it off whenever you like, and the app keeps working with what you've chosen to share.",
  },
] as const;

function CheckIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="21"
      height="21"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {/* i-check from the design's sprite */}
      <path d="M4.8 12.6l4.6 4.6L19.2 7.4" />
    </svg>
  );
}

export function PrivacySection() {
  return (
    <section className="py-[clamp(72px,9vw,132px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div data-reveal>
          <SectionHeading
            eyebrow="Privacy"
            title="Privacy first, by architecture"
            lede="Health data is about as personal as it gets. So the design keeps it where it belongs rather than asking you to trust a promise."
          />
        </div>

        <ul role="list" data-reveal className="grid gap-[18px] min-[860px]:grid-cols-3">
          {CHECKS.map((check) => (
            <li
              key={check.id}
              className="rounded-[24px] border border-ink/[0.06] bg-white p-[clamp(24px,2.6vw,30px)] shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)]"
            >
              <div className="mb-5 grid size-[42px] place-items-center rounded-full bg-accent/[0.11] text-accent-deep">
                <CheckIcon />
              </div>
              <h3 className="mb-[9px] text-[clamp(1.0625rem,1.4vw,1.2rem)] leading-[1.28] font-semibold tracking-[-0.012em] text-ink">
                {check.title}
              </h3>
              <p className="text-[0.9375rem] leading-[1.56] text-ink-muted">{check.copy}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
