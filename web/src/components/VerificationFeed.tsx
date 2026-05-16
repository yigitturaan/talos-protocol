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
  { label: string; color: "green" | "red" | "amber" | "cyan"; layers: string }
> = {
  committed: {
    label: "COMMITTED",
    color: "cyan",
    layers: "---",
  },
  passed: {
    label: "PASSED",
    color: "green",
    layers: "H:OK O:OK P:OK",
  },
  failed: {
    label: "REJECTED",
    color: "red",
    layers: "",
  },
  softReject: {
    label: "SOFT REJECT",
    color: "amber",
    layers: "H:OK O:DRIFT",
  },
  refunded: {
    label: "REFUNDED",
    color: "amber",
    layers: "---",
  },
  slashed: {
    label: "SLASHED",
    color: "red",
    layers: "---",
  },
};

function failureLayers(code?: number): string {
  if (code === 1) return "H:FAIL O:-- P:--";
  if (code === 2) return "H:OK O:FAIL P:--";
  if (code === 3) return "H:OK O:OK P:FAIL";
  return "H:?? O:?? P:??";
}

function EventCard({ event: e }: { event: VerificationEvent }) {
  const cfg = typeConfig[e.type];
  const layers =
    e.type === "failed" ? failureLayers(e.failureCode) : cfg.layers;

  return (
    <div className="flex items-start gap-3 py-2 px-2 border-b border-border-subtle last:border-0 hover:bg-bg-elevated/50 transition-colors">
      <div className="pt-0.5">
        <Pulse color={cfg.color} size="md" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span
            className={`text-[10px] font-bold ${
              cfg.color === "green"
                ? "text-accent-green"
                : cfg.color === "red"
                  ? "text-accent-red"
                  : cfg.color === "amber"
                    ? "text-accent-amber"
                    : "text-accent-cyan"
            }`}
          >
            {cfg.label}
          </span>
          {e.agent && (
            <span className="text-[10px] text-text-secondary">
              {formatAddress(e.agent)}
            </span>
          )}
          {e.intentId && (
            <span className="text-[10px] text-text-secondary opacity-50">
              {e.intentId.slice(0, 10)}...
            </span>
          )}
        </div>
        <div className="flex items-center gap-3 mt-0.5">
          <span className="text-[10px] text-text-secondary font-mono">
            {layers}
          </span>
          {e.amount && (
            <span className="text-[10px] text-text-secondary">
              {formatEther(e.amount)} refunded
            </span>
          )}
          {e.slashAmount && (
            <span className="text-[10px] text-accent-red">
              -{formatEther(e.slashAmount)} MON slashed
            </span>
          )}
          {e.deviationBps !== undefined && e.deviationBps > 0 && (
            <span className="text-[10px] text-accent-amber">
              {(e.deviationBps / 100).toFixed(1)}% drift
            </span>
          )}
        </div>
      </div>
      <span className="text-[9px] text-text-secondary opacity-50 whitespace-nowrap">
        #{e.blockNumber.toString()}
      </span>
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

      <div className="grid grid-cols-2 gap-px">
        <Panel title="Protected Funds">
          <p className="text-accent-green text-lg font-mono">
            {totalProtected > 0n
              ? `${formatEther(totalProtected)} MON`
              : "0"}
          </p>
        </Panel>
        <Panel title="Blocked Txns">
          <p className="text-accent-red text-lg font-mono">{blockedCount}</p>
        </Panel>
      </div>
    </div>
  );
}
