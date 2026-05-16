"use client";

import { useAccount, useBlockNumber } from "wagmi";
import { useEffect, useState } from "react";
import { Pulse } from "../ui/Pulse";
import { formatAddress } from "@/lib/format";

export function StatusBar() {
  const { address, isConnected } = useAccount();
  const { dataUpdatedAt } = useBlockNumber({ watch: true });
  const [latency, setLatency] = useState(0);

  useEffect(() => {
    if (dataUpdatedAt > 0) {
      const now = Date.now();
      const diff = now - dataUpdatedAt;
      if (diff < 5000) setLatency(diff);
    }
  }, [dataUpdatedAt]);

  return (
    <footer className="flex items-center justify-between px-6 py-2 border-t border-border-subtle/50 bg-bg-base/80 backdrop-blur-md text-[11px] text-text-secondary/70">
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-1">
          <Pulse
            color={latency < 500 ? "green" : latency < 1000 ? "amber" : "red"}
          />
          <span>{latency > 0 ? `${latency}ms` : "..."}</span>
        </div>
      </div>

      <div className="flex items-center gap-3">
        {isConnected && address ? (
          <>
            <Pulse color="green" />
            <span>{formatAddress(address)}</span>
          </>
        ) : (
          <>
            <Pulse color="amber" />
            <span>not connected</span>
          </>
        )}
      </div>
    </footer>
  );
}
