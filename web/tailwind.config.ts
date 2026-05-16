import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-inter)", "sans-serif"],
        mono: ["var(--font-mono)", "monospace"],
      },
      colors: {
        bg: {
          base: "#0f0f13",
          panel: "#15151c",
          elevated: "#1c1b26",
        },
        border: {
          subtle: "#2d2a3d",
        },
        text: {
          primary: "#f4f4f5",
          secondary: "#a1a1aa",
        },
        accent: {
          cyan: "#39d0d8",
          purple: "#836ef9",
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
