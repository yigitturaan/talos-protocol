import type { Address } from "viem";

export interface AgentClaim {
  priceFeed: Address;
  claimedPrice: bigint;
  reasoning: string;
  action: string;
  protocol: Address;
  expectedOutputMin: bigint;
  timestamp: bigint;
  expiry: bigint;
}

export enum EscrowStatus {
  Locked = 0,
  Committed = 1,
  Verified = 2,
  Executed = 3,
  Refunded = 4,
  Expired = 5,
}

export interface Escrow {
  intentId: `0x${string}`;
  owner: Address;
  agent: Address;
  token: Address;
  amount: bigint;
  createdAt: bigint;
  expiry: bigint;
  status: EscrowStatus;
  commitHash: `0x${string}`;
  verified: boolean;
}

export interface Reputation {
  agent: Address;
  score: number;
  totalVerifications: number;
  passed: number;
  failed: number;
  totalVolume: bigint;
  stake: bigint;
  registeredAt: bigint;
  lastVerified: bigint;
  isBanned: boolean;
}

export interface VerificationRecord {
  intentId: `0x${string}`;
  agent: Address;
  decision: number;
  hashMatched: boolean;
  oracleMatched: boolean;
  policyPassed: boolean;
  failureCode: number;
  claimedPrice: bigint;
  oraclePrice: bigint;
  priceDeviationBps: number;
  verifiedAt: bigint;
}
