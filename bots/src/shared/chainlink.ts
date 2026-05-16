import type { Address, PublicClient } from "viem";

const aggregatorV3Abi = [
  {
    type: "function",
    name: "latestRoundData",
    inputs: [],
    outputs: [
      { name: "roundId", type: "uint80" },
      { name: "answer", type: "int256" },
      { name: "startedAt", type: "uint256" },
      { name: "updatedAt", type: "uint256" },
      { name: "answeredInRound", type: "uint80" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
  },
] as const;

export interface PriceData {
  price: bigint;
  decimals: number;
  updatedAt: bigint;
  priceFloat: number;
}

export async function readChainlinkPrice(
  client: PublicClient,
  feedAddress: Address,
): Promise<PriceData> {
  const [roundData, decimals] = await Promise.all([
    client.readContract({
      address: feedAddress,
      abi: aggregatorV3Abi,
      functionName: "latestRoundData",
    }),
    client.readContract({
      address: feedAddress,
      abi: aggregatorV3Abi,
      functionName: "decimals",
    }),
  ]);

  const answer = roundData[1];
  const updatedAt = roundData[3];

  return {
    price: answer,
    decimals,
    updatedAt,
    priceFloat: Number(answer) / 10 ** decimals,
  };
}

export function calculateRSI(prices: number[], period = 14): number {
  if (prices.length < period + 1) return 50;

  let gains = 0;
  let losses = 0;

  for (let i = prices.length - period; i < prices.length; i++) {
    const change = prices[i] - prices[i - 1];
    if (change > 0) gains += change;
    else losses += -change;
  }

  if (losses === 0) return 100;
  const rs = gains / losses;
  return 100 - 100 / (1 + rs);
}
