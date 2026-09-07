import { siteConfig } from "@/site.config";

export default function sitemap() {
  return [{ url: `${siteConfig.siteUrl}/`, lastModified: new Date() }];
}
