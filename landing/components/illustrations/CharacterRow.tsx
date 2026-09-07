// "Meet Ripple" companion cards from sac-landing §6. The five character arts
// are inlined verbatim from Open Design assets/images/stress-ai-coach/*.svg
// (HTML comments from the source files dropped; every drawn element kept) so
// the cards carry no image requests and the hover lift stays pure CSS.
import type { ReactNode } from "react";

const rippleArt = (
    <svg viewBox="0 0 100 100" role="img" aria-label="Ripple, a blue water-drop companion" className="h-[74px] w-[74px]">
      <ellipse cx="50" cy="55" rx="26" ry="28" fill="#4FC3F7" />
      <ellipse cx="50" cy="62" rx="18" ry="20" fill="#B3E5FC" />
      <circle cx="50" cy="38" r="20" fill="#4FC3F7" />
      <circle cx="50" cy="42" r="14" fill="#E1F5FE" />
      <circle cx="40" cy="24" r="5" fill="#4FC3F7" />
      <circle cx="60" cy="24" r="5" fill="#4FC3F7" />
      <circle cx="43" cy="40" r="3" fill="#101223" />
      <circle cx="57" cy="40" r="3" fill="#101223" />
      <ellipse cx="50" cy="46" rx="1.6" ry="1.2" fill="#101223" />
      <path d="M44 50 Q50 54 56 50" stroke="#101223" strokeWidth="1.2" fill="none" strokeLinecap="round" />
    </svg>
);

const blossomArt = (
    <svg viewBox="0 0 100 100" role="img" aria-label="Blossom, a green leaf companion" className="h-[74px] w-[74px]">
      <ellipse cx="50" cy="62" rx="24" ry="22" fill="#A5D6A7" />
      <ellipse cx="50" cy="68" rx="16" ry="14" fill="#E8F5E9" />
      <path d="M28 38 L36 18 L48 30 Z" fill="#A5D6A7" />
      <path d="M72 38 L64 18 L52 30 Z" fill="#A5D6A7" />
      <circle cx="50" cy="40" r="20" fill="#A5D6A7" />
      <path d="M30 42 Q50 56 70 42 Q60 50 50 50 Q40 50 30 42 Z" fill="#C8E6C9" />
      <circle cx="42" cy="42" r="3" fill="#1B5E20" />
      <circle cx="58" cy="42" r="3" fill="#1B5E20" />
      <ellipse cx="50" cy="48" rx="2" ry="1.5" fill="#1B5E20" />
      <path d="M44 52 Q50 56 56 52" stroke="#1B5E20" strokeWidth="1.2" fill="none" strokeLinecap="round" />
      <path d="M50 20 Q44 14 46 8 Q52 12 50 20 Z" fill="#66BB6A" />
      <path d="M50 20 L48 12" stroke="#388E3C" strokeWidth="0.8" />
      <path d="M70 70 Q84 60 82 76 Q78 80 70 76 Z" fill="#A5D6A7" />
      <path d="M75 70 Q82 65 80 75" stroke="#66BB6A" strokeWidth="0.8" fill="none" />
    </svg>
);

const emberArt = (
    <svg viewBox="0 0 100 100" role="img" aria-label="Ember, a warm flame companion" className="h-[74px] w-[74px]">
      <path d="M30 60 Q20 40 30 20 Q40 30 38 50 Q44 30 50 18 Q56 30 62 50 Q60 30 70 20 Q80 40 70 60 Z" fill="#FF7043" opacity="0.4" />
      <ellipse cx="50" cy="62" rx="24" ry="22" fill="#FFAB91" />
      <ellipse cx="50" cy="68" rx="16" ry="14" fill="#FFE0B2" />
      <path d="M28 38 L34 18 L46 32 Z" fill="#FFAB91" />
      <path d="M72 38 L66 18 L54 32 Z" fill="#FFAB91" />
      <circle cx="50" cy="40" r="20" fill="#FFAB91" />
      <path d="M30 44 Q50 58 70 44 Q60 52 50 52 Q40 52 30 44 Z" fill="#FFCC80" />
      <path d="M50 18 Q45 12 50 4 Q55 12 50 18 Z" fill="#FF5722" />
      <circle cx="42" cy="42" r="3" fill="#BF360C" />
      <circle cx="58" cy="42" r="3" fill="#BF360C" />
      <ellipse cx="50" cy="48" rx="2" ry="1.5" fill="#BF360C" />
      <path d="M44 52 Q50 56 56 52" stroke="#BF360C" strokeWidth="1.2" fill="none" strokeLinecap="round" />
      <path d="M70 70 Q84 58 86 76 Q80 84 70 78 Z" fill="#FFAB91" />
      <path d="M75 72 Q83 64 82 76 Q78 78 75 72" fill="#FF5722" />
    </svg>
);

const lumiArt = (
    <svg viewBox="0 0 100 100" role="img" aria-label="Lumi, a night-owl companion" className="h-[74px] w-[74px]">
      <path d="M20 30 L22 24 L24 30 L30 32 L24 34 L22 40 L20 34 L14 32 Z" fill="#FFE082" />
      <path d="M80 24 L81 20 L82 24 L86 25 L82 26 L81 30 L80 26 L76 25 Z" fill="#FFE082" />
      <ellipse cx="50" cy="62" rx="24" ry="24" fill="#7986CB" />
      <ellipse cx="50" cy="68" rx="16" ry="16" fill="#C5CAE9" />
      <path d="M30 30 L40 18 L44 30 Z" fill="#7986CB" />
      <path d="M70 30 L60 18 L56 30 Z" fill="#7986CB" />
      <circle cx="50" cy="40" r="22" fill="#7986CB" />
      <circle cx="42" cy="42" r="7" fill="#FFE082" />
      <circle cx="58" cy="42" r="7" fill="#FFE082" />
      <circle cx="42" cy="42" r="4" fill="#1A237E" />
      <circle cx="58" cy="42" r="4" fill="#1A237E" />
      <circle cx="44" cy="40" r="1.5" fill="#fff" />
      <circle cx="60" cy="40" r="1.5" fill="#fff" />
      <path d="M48 50 L52 50 L50 56 Z" fill="#FFB74D" />
      <path d="M50 72 L52 68 L54 72 L58 74 L54 76 L52 80 L50 76 L46 74 L50 72 Z" fill="#FFE082" opacity="0.8" />
      <path d="M28 60 Q22 70 28 78 Q32 70 32 64 Z" fill="#5C6BC0" />
      <path d="M72 60 Q78 70 72 78 Q68 70 68 64 Z" fill="#5C6BC0" />
    </svg>
);

const zephyrArt = (
    <svg viewBox="0 0 100 100" role="img" aria-label="Zephyr, a soft breeze companion" className="h-[74px] w-[74px]">
      <path d="M20 50 Q12 40 22 36 M22 36 Q32 38 30 50" stroke="#D1C4E9" strokeWidth="1.5" fill="none" strokeLinecap="round" />
      <path d="M80 50 Q88 40 78 36 M78 36 Q68 38 70 50" stroke="#D1C4E9" strokeWidth="1.5" fill="none" strokeLinecap="round" />
      <ellipse cx="50" cy="60" rx="24" ry="22" fill="#D1C4E9" />
      <ellipse cx="50" cy="68" rx="16" ry="14" fill="#F3E5F5" />
      <ellipse cx="36" cy="22" rx="6" ry="14" fill="#D1C4E9" transform="rotate(-15 36 22)" />
      <ellipse cx="64" cy="22" rx="6" ry="14" fill="#D1C4E9" transform="rotate(15 64 22)" />
      <ellipse cx="36" cy="22" rx="3" ry="10" fill="#E1BEE7" transform="rotate(-15 36 22)" />
      <ellipse cx="64" cy="22" rx="3" ry="10" fill="#E1BEE7" transform="rotate(15 64 22)" />
      <circle cx="50" cy="40" r="20" fill="#D1C4E9" />
      <circle cx="50" cy="44" r="14" fill="#F3E5F5" />
      <circle cx="42" cy="42" r="3" fill="#4527A0" />
      <circle cx="58" cy="42" r="3" fill="#4527A0" />
      <ellipse cx="50" cy="48" rx="2" ry="1.5" fill="#4527A0" />
      <path d="M44 52 Q50 56 56 52" stroke="#4527A0" strokeWidth="1.2" fill="none" strokeLinecap="round" />
      <circle cx="76" cy="64" r="9" fill="#E1BEE7" />
    </svg>
);

type Character = {
  name: string;
  tag: string;
  starter?: boolean;
  caption: string;
  art: ReactNode;
};

const CHARACTERS: Character[] = [
  { name: "Ripple", tag: "Your starter", starter: true, caption: "The water drop that mirrors your day back to you.", art: rippleArt },
  { name: "Blossom", tag: "Unlockable", caption: "Green and growing — for stretches when you're rebuilding.", art: blossomArt },
  { name: "Ember", tag: "Unlockable", caption: "A steady flame for the weeks that ask a lot of you.", art: emberArt },
  { name: "Lumi", tag: "Unlockable", caption: "Wide-eyed at night — good company for sleep work.", art: lumiArt },
  { name: "Zephyr", tag: "Unlockable", caption: "Light as air, for when things finally settle.", art: zephyrArt },
];

const CARD =
  "group rounded-[24px] border border-ink/[0.06] bg-white px-[22px] pt-6 pb-[26px] text-center " +
  "shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)] " +
  "transition-[transform,box-shadow] duration-300 hover:-translate-y-1.5 hover:shadow-[0_2px_4px_rgba(16,18,35,0.04),0_14px_40px_rgba(16,18,35,0.08)]";

export function CharacterRow() {
  return (
    <ul role="list" className="grid grid-cols-1 gap-[18px] sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-5">
      {CHARACTERS.map((c) => (
        <li key={c.name} className={CARD}>
          <div className="mx-auto mb-[18px] grid size-[104px] place-items-center rounded-full bg-surface transition-colors duration-300 group-hover:bg-tint">
            <div className="transition-transform duration-500 group-hover:-translate-y-[5px] group-hover:-rotate-4">{c.art}</div>
          </div>
          <span
            className={
              "mb-[14px] inline-block rounded-full px-[11px] py-1 font-[family-name:var(--font-mono)] text-[0.625rem] uppercase tracking-[0.1em] " +
              (c.starter ? "bg-accent/[0.12] text-accent-deep" : "bg-ink/[0.07] text-ink-muted")
            }
          >
            {c.tag}
          </span>
          <h3 className="mb-[6px] text-[clamp(1.0625rem,1.4vw,1.2rem)] font-semibold leading-[1.28] tracking-[-0.012em] text-ink">{c.name}</h3>
          <p className="text-[0.875rem] leading-[1.5] text-ink-muted">{c.caption}</p>
        </li>
      ))}
    </ul>
  );
}
