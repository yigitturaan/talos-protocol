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
  badgeColor = "text-accent-cyan",
}: PanelProps) {
  return (
    <div
      className={clsx(
        "bg-bg-panel border border-border-subtle rounded-sm overflow-hidden",
        className,
      )}
    >
      <div className="flex items-center justify-between px-3 py-1.5 border-b border-border-subtle bg-bg-elevated">
        <div className="flex items-center gap-2">
          <span className="text-text-secondary text-[10px]">{">"}</span>
          <span className="text-xs text-text-primary uppercase tracking-wider">
            {title}
          </span>
        </div>
        {badge && (
          <span className={clsx("text-[10px]", badgeColor)}>{badge}</span>
        )}
      </div>
      <div className="p-3">{children}</div>
    </div>
  );
}
