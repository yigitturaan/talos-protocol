import type { Address, PublicClient } from "viem";
import { parseEther } from "viem";

const erc4626Abi = [
  {
    type: "function",
    name: "convertToAssets",
    inputs: [{ name: "shares", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalAssets",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "asset",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
] as const;

export interface VaultSnapshot {
  sharePriceRaw: bigint;
  totalAssets: bigint;
  timestamp: number;
}

const ONE_SHARE = parseEther("1");

export async function readVaultSnapshot(
  client: PublicClient,
  vault: Address,
): Promise<VaultSnapshot> {
  const [sharePriceRaw, totalAssets] = await Promise.all([
    client.readContract({
      address: vault,
      abi: erc4626Abi,
      functionName: "convertToAssets",
      args: [ONE_SHARE],
    }),
    client.readContract({
      address: vault,
      abi: erc4626Abi,
      functionName: "totalAssets",
    }),
  ]);

  return { sharePriceRaw, totalAssets, timestamp: Math.floor(Date.now() / 1000) };
}

export function estimateAPY(older: VaultSnapshot, newer: VaultSnapshot): number {
  if (older.sharePriceRaw === 0n) return 0;
  const elapsed = newer.timestamp - older.timestamp;
  if (elapsed <= 0) return 0;

  const priceDelta = Number(newer.sharePriceRaw - older.sharePriceRaw);
  const basePrice = Number(older.sharePriceRaw);
  const periodReturn = priceDelta / basePrice;
  const secondsPerYear = 365 * 24 * 3600;

  return (periodReturn * secondsPerYear) / elapsed * 100;
}
