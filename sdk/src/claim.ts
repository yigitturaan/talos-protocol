import { encodeAbiParameters, keccak256 } from "viem";
import type { AgentClaim } from "./types.js";

/**
 * ABI parameter types matching Solidity ClaimEncoder.encode() EXACTLY.
 * Order: priceFeed, claimedPrice, reasoning, action, protocol,
 *        expectedOutputMin, timestamp, expiry
 * SDK and contract MUST produce byte-identical output (Anayasa #9).
 */
const CLAIM_ABI_PARAMS = [
  { name: "priceFeed", type: "address" as const },
  { name: "claimedPrice", type: "uint256" as const },
  { name: "reasoning", type: "string" as const },
  { name: "action", type: "string" as const },
  { name: "protocol", type: "address" as const },
  { name: "expectedOutputMin", type: "uint256" as const },
  { name: "timestamp", type: "uint64" as const },
  { name: "expiry", type: "uint64" as const },
] as const;

export function encodeClaim(claim: AgentClaim): `0x${string}` {
  return encodeAbiParameters(CLAIM_ABI_PARAMS, [
    claim.priceFeed,
    claim.claimedPrice,
    claim.reasoning,
    claim.action,
    claim.protocol,
    claim.expectedOutputMin,
    claim.timestamp,
    claim.expiry,
  ]);
}

export function hashClaim(claim: AgentClaim): `0x${string}` {
  return keccak256(encodeClaim(claim));
}
