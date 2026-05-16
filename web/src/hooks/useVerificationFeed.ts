"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  createPublicClient,
  http,
  parseAbiItem,
  formatEther,
  type Log,
} from "viem";
import { monadTestnet } from "@talos-protocol/sdk";
import { TALOS_PROTOCOL_ADDRESS } from "@/lib/contracts";
import { talosProtocolAbi } from "@talos-protocol/sdk";

export type VerificationEvent = {
  id: string;
  intentId: string;
  agent: string;
  type: "committed" | "passed" | "failed" | "softReject" | "refunded" | "slashed";
  blockNumber: bigint;
  txHash: string;
  failureCode?: number;
  deviationBps?: number;
  amount?: bigint;
  slashAmount?: bigint;
  timestamp: number;
};

const MAX_EVENTS = 50;
const POLL_INTERVAL = 2000;
const LOOKBACK_BLOCKS = 100n;

const client = createPublicClient({
  chain: monadTestnet,
  transport: http("https://testnet-rpc.monad.xyz"),
});

export function useVerificationFeed() {
  const [events, setEvents] = useState<VerificationEvent[]>([]);
  const [totalProtected, setTotalProtected] = useState(0n);
  const [blockedCount, setBlockedCount] = useState(0);
  const lastBlockRef = useRef<bigint>(0n);
  const seenTxsRef = useRef<Set<string>>(new Set());

  const addEvents = useCallback((newEvents: VerificationEvent[]) => {
    setEvents((prev) => {
      const merged = [...newEvents, ...prev];
      const unique = merged.filter((e, i) => merged.findIndex((x) => x.id === e.id) === i);
      return unique.slice(0, MAX_EVENTS);
    });
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function poll() {
      try {
        const currentBlock = await client.getBlockNumber();

        if (lastBlockRef.current === 0n) {
          lastBlockRef.current = currentBlock > LOOKBACK_BLOCKS
            ? currentBlock - LOOKBACK_BLOCKS
            : 0n;
        }

        const fromBlock = lastBlockRef.current + 1n;
        if (fromBlock > currentBlock) return;

        const logs = await client.getContractEvents({
          address: TALOS_PROTOCOL_ADDRESS,
          abi: talosProtocolAbi,
          fromBlock,
          toBlock: currentBlock,
        });

        lastBlockRef.current = currentBlock;

        if (cancelled || logs.length === 0) return;

        const newEvents: VerificationEvent[] = [];

        for (const log of logs) {
          const txHash = log.transactionHash ?? "";
          const eventName = (log as any).eventName as string;
          const args = (log as any).args ?? {};
          const id = `${txHash}-${eventName}-${log.logIndex}`;

          if (seenTxsRef.current.has(id)) continue;
          seenTxsRef.current.add(id);

          const base = {
            blockNumber: log.blockNumber ?? 0n,
            txHash,
            timestamp: Date.now(),
          };

          switch (eventName) {
            case "ClaimCommitted":
              newEvents.push({
                ...base,
                id,
                intentId: args.intentId ?? "",
                agent: args.agent ?? "",
                type: "committed",
              });
              break;
            case "VerificationPassed":
              newEvents.push({
                ...base,
                id,
                intentId: args.intentId ?? "",
                agent: args.agent ?? "",
                type: "passed",
              });
              break;
            case "VerificationFailed":
              newEvents.push({
                ...base,
                id,
                intentId: args.intentId ?? "",
                agent: args.agent ?? "",
                type: "failed",
                failureCode: Number(args.failureCode ?? 0),
              });
              setBlockedCount((c) => c + 1);
              break;
            case "SoftRejection":
              newEvents.push({
                ...base,
                id,
                intentId: args.intentId ?? "",
                agent: "",
                type: "softReject",
                deviationBps: Number(args.deviationBps ?? 0),
              });
              break;
            case "EscrowRefunded":
              newEvents.push({
                ...base,
                id,
                intentId: args.intentId ?? "",
                agent: args.owner ?? "",
                type: "refunded",
                amount: args.amount,
              });
              setTotalProtected((v) => v + (args.amount ?? 0n));
              break;
            case "AgentSlashed":
              newEvents.push({
                ...base,
                id,
                intentId: "",
                agent: args.agent ?? "",
                type: "slashed",
                slashAmount: args.slashAmount,
              });
              break;
          }
        }

        if (newEvents.length > 0) {
          addEvents(newEvents);
        }
      } catch {
        // RPC error — retry next interval
      }
    }

    poll();
    const interval = setInterval(poll, POLL_INTERVAL);

    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [addEvents]);

  return { events, totalProtected, blockedCount };
}
