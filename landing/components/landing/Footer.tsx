// Site footer, ported from sac-landing: brand + product/resources columns
// over the legal line. Links resolve from siteConfig — the disclaimer is the
// approved "not medical advice" copy, verbatim.
import { RippleMark } from "@/components/illustrations/RippleMark";
import { siteConfig } from "@/site.config";

const PRODUCT_LINKS = [
  { label: "60-second stress quiz", href: siteConfig.quizPath },
  { label: "How scoring works", href: "#score" },
  { label: "Calm tools", href: "#calm" },
  { label: "FAQ", href: "#faq" },
] as const;

const RESOURCE_LINKS = [
  { label: "Documentation", href: siteConfig.docsBaseUrl, external: true },
  { label: "Privacy policy", href: siteConfig.privacyUrl, external: true },
  { label: "Terms of use", href: siteConfig.termsUrl, external: true },
  { label: siteConfig.supportEmail, href: `mailto:${siteConfig.supportEmail}`, external: false },
] as const;

export function Footer() {
  return (
    <footer className="bg-ink py-[clamp(48px,5vw,68px)] pb-[34px] text-white/72">
      <div className="mx-auto w-full max-w-[1180px] px-[clamp(20px,5vw,40px)]">
        <div className="grid gap-[34px] border-b border-white/14 pb-9 min-[761px]:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1fr)] max-[760px]:grid-cols-2">
          <div className="max-[760px]:col-span-full">
            <div className="flex items-center gap-2.5">
              <RippleMark size={32} />
              <span className="text-[1.0625rem] font-semibold tracking-[-0.02em] text-white">{siteConfig.name}</span>
            </div>
            <p className="mt-[14px] max-w-[34ch] text-[0.875rem] leading-[1.55]">
              Understand your stress. Do something about it. For iPhone and Apple&nbsp;Watch.
            </p>
          </div>

          <nav aria-label="Product">
            <h4 className="mb-[15px] font-[family-name:var(--font-mono)] text-[0.625rem] font-normal uppercase tracking-[0.13em] text-white/50">
              Product
            </h4>
            <ul role="list" className="grid gap-[11px]">
              {PRODUCT_LINKS.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    className="border-b border-transparent pb-px text-[0.875rem] text-white/78 transition-colors duration-200 hover:border-white/50 hover:text-white"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>

          <nav aria-label="Resources">
            <h4 className="mb-[15px] font-[family-name:var(--font-mono)] text-[0.625rem] font-normal uppercase tracking-[0.13em] text-white/50">
              Resources
            </h4>
            <ul role="list" className="grid gap-[11px]">
              {RESOURCE_LINKS.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    {...(link.external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
                    className="border-b border-transparent pb-px text-[0.875rem] text-white/78 transition-colors duration-200 hover:border-white/50 hover:text-white"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </div>

        <div className="flex flex-wrap items-center gap-x-[26px] gap-y-3 pt-[26px] text-[0.75rem] text-white/55">
          <span>© 2026 {siteConfig.name}</span>
          <span className="max-w-[62ch]">
            Stress AI Coach is a wellness tool — not a medical device, and not a substitute for professional care.
          </span>
        </div>
      </div>
    </footer>
  );
}
