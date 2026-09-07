// Black "Download on the App Store" badge, geometry reproduced from the Open
// Design appstore-badge.svg asset (Apple mark paths + type, black rounded
// plate). Links to the single source of truth for the app's store URL.
import { siteConfig } from "@/site.config";

export function AppStoreBadge({ className }: { className?: string }) {
  return (
    <a
      href={siteConfig.appStoreUrl}
      target="_blank"
      rel="noopener"
      aria-label="Download Stress AI Coach on the App Store"
      className={
        "inline-flex overflow-hidden rounded-[9px] leading-[0] " +
        "shadow-[0_1px_2px_rgba(16,18,35,0.04),0_4px_14px_rgba(16,18,35,0.05)] " +
        "transition-[transform,box-shadow] duration-200 hover:-translate-y-0.5 hover:shadow-[0_2px_4px_rgba(16,18,35,0.04),0_14px_40px_rgba(16,18,35,0.08)] active:translate-y-0 " +
        (className ?? "")
      }
    >
      <svg viewBox="0 0 135 40" aria-hidden="true" focusable="false" className="block h-auto w-[158px]">
        <rect x="0.5" y="0.5" width="134" height="39" rx="8" fill="#000000" stroke="#FFFFFF" strokeOpacity="0.25" />
        <g fill="#FFFFFF">
          <path d="M23.1 20.6c0-3 2.45-4.45 2.56-4.52-1.4-2.05-3.57-2.33-4.32-2.36-1.84-.19-3.6 1.09-4.53 1.09-.94 0-2.38-1.07-3.92-1.04-2 .03-3.86 1.18-4.89 2.98-2.1 3.64-.53 9.02 1.49 11.97 1 1.43 2.18 3.03 3.73 2.97 1.5-.06 2.07-.96 3.88-.96 1.8 0 2.32.96 3.9.93 1.61-.03 2.63-1.45 3.6-2.88 1.15-1.66 1.62-3.28 1.64-3.36-.04-.02-3.14-1.2-3.17-4.76l-.37.94z" />
          <path d="M21.7 11.9c.83-1 1.39-2.39 1.24-3.78-1.2.05-2.66.8-3.52 1.8-.77.89-1.45 2.31-1.27 3.67 1.34.1 2.72-.68 3.55-1.69z" />
          <text x="39" y="18" fontFamily="-apple-system, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif" fontSize="7.5">
            Download on the
          </text>
          <text x="39" y="31" fontFamily="-apple-system, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif" fontSize="11.5" fontWeight={600}>
            App Store
          </text>
        </g>
      </svg>
    </a>
  );
}
