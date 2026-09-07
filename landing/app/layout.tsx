import type { Metadata } from "next";
import { Roboto } from "next/font/google";
import { siteConfig } from "@/site.config";
import "./globals.css";

const roboto = Roboto({ weight: ["400", "500", "700"], subsets: ["latin"], variable: "--font-roboto", display: "swap" });

export const metadata: Metadata = {
  title: { default: `${siteConfig.name} — ${siteConfig.tagline}`, template: `%s · ${siteConfig.name}` },
  description: "Stress AI Coach turns the health data your iPhone already collects into a daily 0–100 stress score, then helps you act on it with an AI wellness coach and calm tools. iPhone + Apple Watch.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={roboto.variable}>
      <body className="font-[family-name:var(--font-roboto)] text-ink bg-white antialiased">{children}</body>
    </html>
  );
}
