import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    include: ["test/**/*.testnet.test.ts"],
    testTimeout: 120_000,
  },
});
