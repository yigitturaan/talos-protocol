"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useBlockNumber, useChainId } from "wagmi";
import { Pulse } from "../ui/Pulse";

const chainNames: Record<number, string> = {
  10143: "Monad Testnet",
  143: "Monad",
};

export function TopBar() {
  const chainId = useChainId();
  const { data: blockNumber } = useBlockNumber({ watch: true });

  const chainLabel = chainNames[chainId] || `Chain ${chainId}`;

  return (
    <header className="flex items-center justify-between px-6 py-3 border-b border-border-subtle/50 bg-bg-base/80 backdrop-blur-md sticky top-0 z-50">
      <div className="flex items-baseline gap-2">
        <span className="text-accent-purple font-extrabold text-lg tracking-widest drop-shadow-sm">
          TALOS
        </span>
        <span className="text-text-secondary/80 text-xs font-medium tracking-[0.2em]">TERMINAL</span>
      </div>

      <div className="flex items-center gap-2 text-xs text-text-secondary">
        <Pulse color="green" />
        <span>{chainLabel}</span>
        <span className="text-border-subtle">|</span>
        <span>
          Block #{blockNumber ? blockNumber.toLocaleString() : "..."}
        </span>
      </div>

      <ConnectButton
        accountStatus="address"
        chainStatus="icon"
        showBalance={false}
      />
    </header>
  );
}
