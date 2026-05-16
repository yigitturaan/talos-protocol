"use client";

import clsx from "clsx";

interface PanelProps {
  title: string;
  className?: string;
  children: React.ReactNode;
  badge?: string;
  badgeColor?: string;
}

export function Panel({
  title,
  className,
  children,
  badge,
  badgeColor = "text-accent-purple",
}: PanelProps) {
  return (
    <div
      className={clsx(
        "bg-bg-panel border border-border-subtle/50 rounded-xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-300",
        className,
      )}
    >
      <div className="flex items-center justify-between px-4 py-3 border-b border-border-subtle/30 bg-bg-elevated/30 backdrop-blur-sm">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-text-primary tracking-wide">
            {title}
          </span>
        </div>
        {badge && (
          <span className={clsx("text-[10px] font-medium px-2 py-0.5 rounded-full bg-bg-base/50", badgeColor)}>{badge}</span>
        )}
      </div>
      <div className="p-3">{children}</div>
    </div>
  );
}
