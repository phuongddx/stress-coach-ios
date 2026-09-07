// Ripple — the water-drop mascot mark. Geometry inlined verbatim from
// sac-landing's brand mark / assets/images/stress-ai-coach/ripple.svg so it can
// sit inside chips, chat headers, and dark bands without an <img> round-trip.
export function RippleMark({ size = 32 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" aria-hidden="true" focusable="false">
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
}
