"use client";

import { Pulse } from "./ui/Pulse";
import { Panel } from "./ui/Panel";
import { formatAddress } from "@/lib/format";
import {
  useVerificationFeed,
  type VerificationEvent,
} from "@/hooks/useVerificationFeed";
import { formatEther } from "viem";

const typeConfig: Record<
  VerificationEvent["type"],
  { label: string; color: "green" | "red" | "amber" | "purple" | "cyan" }
> = {
  committed: {
    label: "COMMITTED",
    color: "purple",
  },
  passed: {
    label: "PASSED",
    color: "green",
  },
  failed: {
    label: "REJECTED",
    color: "red",
  },
  softReject: {
    label: "SOFT REJECT",
    color: "amber",
  },
  refunded: {
    label: "REFUNDED",
    color: "amber",
  },
  slashed: {
    label: "SLASHED",
    color: "red",
  },
};

function EventCard({ event: e }: { event: VerificationEvent }) {
  const cfg = typeConfig[e.type];

  return (
    <div className="flex items-center gap-4 py-3 px-4 border-b border-border-subtle/50 last:border-0 hover:bg-bg-elevated/40 transition-all duration-300 animate-fade-up shadow-sm mb-1 rounded-md">
      <div className="flex-shrink-0">
        <Pulse color={cfg.color} size="md" />
      </div>
      <div className="flex-1 min-w-0 flex flex-col sm:flex-row sm:items-center justify-between gap-1 sm:gap-4">
        <div className="flex items-center gap-2">
          <span
            className={`text-xs font-semibold tracking-wide ${
              cfg.color === "green"
                ? "text-accent-green"
                : cfg.color === "red"
                  ? "text-accent-red"
                  : cfg.color === "amber"
                    ? "text-accent-amber"
                    : cfg.color === "purple"
                      ? "text-accent-purple"
                      : "text-accent-cyan"
            }`}
          >
            {cfg.label}
          </span>
          {e.agent && (
            <span className="text-[11px] text-text-secondary/70">
              {formatAddress(e.agent)}
            </span>
          )}
        </div>
        
        <div className="flex flex-col sm:flex-row sm:items-center gap-3">
          {e.amount && (
            <span className="text-xs sm:text-sm text-text-secondary">
              {formatEther(e.amount)} <span className="opacity-50">USDC</span>
            </span>
          )}
          {e.slashAmount && (
            <span className="text-xs sm:text-sm text-accent-red font-bold">
              -{formatEther(e.slashAmount)} MON
            </span>
          )}
          {e.deviationBps !== undefined && e.deviationBps > 0 && (
            <span className="text-xs sm:text-sm text-accent-amber font-bold">
              {(e.deviationBps / 100).toFixed(1)}% drift
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

export function VerificationFeed() {
  const { events, totalProtected, blockedCount } = useVerificationFeed();

  return (
    <div className="space-y-2">
      <Panel title="Verification Feed" badge="LIVE">
        {events.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-text-secondary text-xs">
              Listening for protocol events...
            </p>
            <p className="text-text-secondary text-[10px] mt-1 opacity-50">
              Run bots to see live verification flow
            </p>
          </div>
        ) : (
          <div className="max-h-[50vh] overflow-y-auto -m-3">
            {events.map((e) => (
              <EventCard key={e.id} event={e} />
            ))}
          </div>
        )}
      </Panel>

      <div className="grid grid-cols-2 gap-4 mt-4">
        <Panel title="Protected Funds">
          <p className="text-accent-green text-3xl font-bold font-mono py-2">
            {totalProtected > 0n
              ? `${formatEther(totalProtected)} MON`
              : "0"}
          </p>
        </Panel>
        <Panel title="Blocked Txns">
          <p className="text-accent-red text-3xl font-bold font-mono py-2">{blockedCount}</p>
        </Panel>
      </div>
    </div>
  );
}
