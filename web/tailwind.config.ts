import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        mono: ["var(--font-mono)", "monospace"],
      },
      colors: {
        bg: {
          base: "#0a0e14",
          panel: "#111820",
          elevated: "#1a2230",
        },
        border: {
          subtle: "#1f2933",
        },
        text: {
          primary: "#e6edf3",
          secondary: "#768390",
        },
        accent: {
          cyan: "#39d0d8",
          green: "#3fb950",
          red: "#f85149",
          amber: "#d29922",
        },
      },
    },
  },
  plugins: [],
};

export default config;
