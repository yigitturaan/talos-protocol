"use client";

import clsx from "clsx";

interface PulseProps {
  color?: "green" | "red" | "amber" | "cyan";
  size?: "sm" | "md";
}

const colorMap = {
  green: "bg-accent-green",
  red: "bg-accent-red",
  amber: "bg-accent-amber",
  cyan: "bg-accent-cyan",
};

export function Pulse({ color = "green", size = "sm" }: PulseProps) {
  const sizeClass = size === "sm" ? "w-1.5 h-1.5" : "w-2 h-2";
  return (
    <span className="relative inline-flex">
      <span
        className={clsx(
          sizeClass,
          "rounded-full animate-pulse-glow",
          colorMap[color],
        )}
      />
    </span>
  );
}
