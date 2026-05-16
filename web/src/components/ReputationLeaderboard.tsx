"use client";

import { useMemo } from "react";
import { formatEther, type Address } from "viem";
import { Panel } from "./ui/Panel";
import { Pulse } from "./ui/Pulse";
import { formatAddress } from "@/lib/format";
import { useReputationBoard, type AgentRow } from "@/hooks/useReputationBoard";

const KNOWN_AGENTS: Address[] = [
  "0xEc98e3A2DFC1D3a3e1f1468c8D7E5dd438730150",
];

function scoreColor(score: number): string {
  if (score >= 1200) return "text-accent-green";
  if (score >= 800) return "text-accent-purple";
  if (score >= 400) return "text-accent-amber";
  return "text-accent-red";
}

function AgentRowCard({
  row,
  rank,
}: {
  row: AgentRow;
  rank: number;
}) {
  const successRate =
    row.totalVerifications > 0
      ? ((row.passed / row.totalVerifications) * 100).toFixed(0)
      : "N/A";

  return (
    <div className="flex items-center gap-3 py-3 px-4 border-b border-border-subtle/50 last:border-0 hover:bg-bg-elevated/40 transition-colors">
      <span className="text-text-secondary text-[11px] w-4 text-right">
        {rank}
      </span>
      <div className="flex items-center gap-2">
        <Pulse color={row.isBanned ? "red" : "green"} />
        <span className="text-xs text-text-primary tracking-wide font-medium">
          {formatAddress(row.agent)}
        </span>
      </div>
      <div className="flex-1" />
      <div className="flex items-center gap-5 text-[11px]">
        <div className="text-right">
          <span className={`font-bold ${scoreColor(row.score)}`}>
            {row.score}
          </span>
          <span className="text-text-secondary/70 ml-1">ELO</span>
        </div>
        <div className="text-right min-w-[3rem]">
          <span className="text-text-primary font-medium">{row.totalVerifications}</span>
          <span className="text-text-secondary/70 ml-1">tx</span>
        </div>
        <div className="text-right min-w-[2.5rem]">
          <span className="text-text-primary font-medium">{successRate}</span>
          <span className="text-text-secondary/70 ml-0.5">%</span>
        </div>
        <div className="text-right min-w-[4rem]">
          <span className="text-text-primary font-medium">
            {formatEther(row.stake)}
          </span>
          <span className="text-text-secondary/70 ml-1">MON</span>
        </div>
      </div>
    </div>
  );
}

export function ReputationLeaderboard() {
  const { rows, loading } = useReputationBoard(KNOWN_AGENTS);

  return (
    <Panel title="Agent Reputation" badge="LEADERBOARD">
      {rows.length === 0 ? (
        <div className="text-center py-8">
          <p className="text-text-secondary text-xs">
            {loading ? "Loading agents..." : "No registered agents found"}
          </p>
        </div>
      ) : (
        <div className="-m-3">
          <div className="flex items-center gap-3 py-2 px-4 text-[10px] text-text-secondary/70 uppercase tracking-wider border-b border-border-subtle/50 bg-bg-base/30">
            <span className="w-4 text-right font-semibold">#</span>
            <span className="font-semibold">Agent</span>
            <div className="flex-1" />
            <span className="w-12 text-right font-semibold">Score</span>
            <span className="w-12 text-right font-semibold">Txns</span>
            <span className="w-10 text-right font-semibold">Win%</span>
            <span className="w-16 text-right font-semibold">Stake</span>
          </div>
          {rows.map((row, i) => (
            <AgentRowCard key={row.agent} row={row} rank={i + 1} />
          ))}
        </div>
      )}
    </Panel>
  );
}
