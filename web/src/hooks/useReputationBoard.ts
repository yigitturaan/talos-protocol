"use client";

import { useEffect, useState } from "react";
import { createPublicClient, http, type Address, getAddress } from "viem";
import { monadTestnet, talosProtocolAbi } from "@talos-protocol/sdk";
import { TALOS_PROTOCOL_ADDRESS } from "@/lib/contracts";

const client = createPublicClient({
  chain: monadTestnet,
  transport: http("https://testnet-rpc.monad.xyz"),
});

export type AgentRow = {
  agent: Address;
  score: number;
  totalVerifications: number;
  passed: number;
  failed: number;
  totalVolume: bigint;
  stake: bigint;
  isBanned: boolean;
};

export function useReputationBoard(knownAgents: Address[]) {
  const [rows, setRows] = useState<AgentRow[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (knownAgents.length === 0) return;

    let cancelled = false;

    async function fetch() {
      setLoading(true);
      try {
        const calls = knownAgents.map((agent) => ({
          address: TALOS_PROTOCOL_ADDRESS,
          abi: talosProtocolAbi,
          functionName: "reputations" as const,
          args: [agent] as const,
        }));

        const results = await client.multicall({ contracts: calls });

        if (cancelled) return;

        const parsed: AgentRow[] = [];
        for (let i = 0; i < results.length; i++) {
          const r = results[i];
          if (r.status !== "success" || !r.result) continue;
          const rep = r.result as any;
          if (rep.stake === 0n) continue;
          parsed.push({
            agent: getAddress(knownAgents[i]),
            score: Number(rep.score),
            totalVerifications: Number(rep.totalVerifications),
            passed: Number(rep.passed),
            failed: Number(rep.failed),
            totalVolume: rep.totalVolume,
            stake: rep.stake,
            isBanned: rep.isBanned,
          });
        }

        parsed.sort((a, b) => b.score - a.score);
        setRows(parsed);
      } catch {
        // silent — retry on next poll
      } finally {
        setLoading(false);
      }
    }

    fetch();
    const interval = setInterval(fetch, 5_000);

    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [knownAgents]);

  return { rows, loading };
}
