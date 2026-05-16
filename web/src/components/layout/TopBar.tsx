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
    <header className="flex items-center justify-between px-4 py-2 border-b border-border-subtle bg-bg-panel">
      <div className="flex items-center gap-3">
        <span className="text-accent-cyan font-bold text-sm tracking-widest">
          TALOS
        </span>
        <span className="text-text-secondary text-xs">TERMINAL</span>
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
