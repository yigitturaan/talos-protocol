import "dotenv/config";
import type { Address } from "viem";

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing env var: ${key}. Copy .env.example to .env and fill in values.`);
  return val;
}

export const PRIVATE_KEY = requireEnv("PRIVATE_KEY") as `0x${string}`;
export const TALOS_PROTOCOL_ADDRESS = requireEnv("TALOS_PROTOCOL_ADDRESS") as Address;
export const RPC_URL = process.env["RPC_URL"] || "https://testnet-rpc.monad.xyz";
export const CHAINLINK_MON_USD = requireEnv("CHAINLINK_MON_USD") as Address;
export const MORPHO_VAULT = (process.env["MORPHO_VAULT"] || "") as Address;
export const EXPLORER_URL = process.env["EXPLORER_URL"] || "https://testnet.monadexplorer.com";

export function txLink(hash: string): string {
  return `${EXPLORER_URL}/tx/${hash}`;
}
