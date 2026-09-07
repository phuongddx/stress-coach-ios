import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// Mirror tsconfig.json "paths": { "@/*": ["./*"] } — Vite's resolver does not
// read tsconfig paths, so the alias is restated here for `@/`-style imports.
export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL(".", import.meta.url)),
    },
  },
});
