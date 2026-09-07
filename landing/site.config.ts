export const siteConfig = {
  name: "Stress AI Coach",
  siteUrl: "https://placeholder.vercel.app", // canonical domain, set at deploy — feeds sitemap, robots, and metadataBase
  tagline: "Understand your stress. Do something about it.",
  appStoreUrl: "https://apps.apple.com/app/stress-ai-coach/id6778478266",
  testFlightUrl: "https://testflight.apple.com/join/yuxPhrec",
  // Store listing isn't live yet (ASC lookup id=6778478266 → 0 results), so download CTAs
  // target TestFlight. At launch, flip this one line to `appStoreUrl`.
  downloadUrl: "https://testflight.apple.com/join/yuxPhrec",
  supportEmail: "support@stressmonitor.app",
  docsBaseUrl: "https://stressmonitor-docs.vercel.app",
  privacyUrl: "https://stressmonitor-docs.vercel.app/legal/privacy",
  termsUrl: "https://stressmonitor-docs.vercel.app/legal/terms",
  quizPath: "/start",
} as const;
