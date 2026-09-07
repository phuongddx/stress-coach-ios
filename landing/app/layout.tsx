import type { Metadata } from "next";
import { Roboto } from "next/font/google";
import { siteConfig } from "@/site.config";
import "./globals.css";

const roboto = Roboto({ weight: ["400", "500", "700"], subsets: ["latin"], variable: "--font-roboto", display: "swap" });

const SITE_URL = "https://PLACEHOLDER.vercel.app"; // canonical domain, set at deploy (mirrors app/sitemap.ts)

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: siteConfig.name,
  applicationCategory: "Health & Fitness",
  operatingSystem: "iOS 18.6+, watchOS 11.6+",
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
};

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: `${siteConfig.name} — ${siteConfig.tagline}`, template: `%s · ${siteConfig.name}` },
  description: "Stress AI Coach turns the health data your iPhone already collects into a daily 0–100 stress score, then helps you act on it with an AI wellness coach and calm tools. iPhone + Apple Watch.",
  openGraph: {
    type: "website",
    siteName: siteConfig.name,
    images: [{ url: "/og.png", width: 1200, height: 630, alt: `${siteConfig.name} — ${siteConfig.tagline}` }],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={roboto.variable}>
      <body className="font-[family-name:var(--font-roboto)] text-ink bg-white antialiased">
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
        {children}
      </body>
    </html>
  );
}
