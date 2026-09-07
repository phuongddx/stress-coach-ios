// Trust strip, ported from sac-landing §3. Copy is the brief's exact,
// honest phrasing (which overrides the source file's "Scores computed on
// your device"): Built on Apple Health · Scores on your device · iPhone + Apple Watch.

function IconHealth() {
  return (
    <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M12 16.4s-3.9-2.4-3.9-5.2a2.2 2.2 0 0 1 3.9-1.4 2.2 2.2 0 0 1 3.9 1.4c0 2.8-3.9 5.2-3.9 5.2Z" />
    </svg>
  );
}

function IconLock() {
  return (
    <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="4.6" y="10.4" width="14.8" height="10.6" rx="2.6" />
      <path d="M8.2 10.4V7.6a3.8 3.8 0 0 1 7.6 0v2.8" />
    </svg>
  );
}

function IconWatch() {
  return (
    <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="6.2" y="6.2" width="11.6" height="11.6" rx="3.4" />
      <path d="M9.2 6.2 9.8 2.6h4.4l.6 3.6M9.2 17.8l.6 3.6h4.4l.6-3.6" />
      <path d="M17.8 10.6h1.6" />
    </svg>
  );
}

const ITEMS = [
  { icon: <IconHealth />, label: "Built on Apple Health" },
  { icon: <IconLock />, label: "Scores on your device" },
  { icon: <IconWatch />, label: "iPhone + Apple Watch" },
] as const;

export function TrustStrip() {
  return (
    <section className="border-t border-[rgba(2,136,209,0.18)] bg-tint py-[clamp(26px,3vw,34px)]">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <ul role="list" className="flex flex-wrap items-center gap-[clamp(18px,3.4vw,44px)]">
          {ITEMS.map((item) => (
            <li key={item.label} className="flex items-center gap-[11px] text-[0.9375rem] font-medium text-ink">
              <span className="text-accent-deep">{item.icon}</span>
              {item.label}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
