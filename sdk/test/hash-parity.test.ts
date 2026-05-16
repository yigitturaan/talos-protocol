import { describe, it, expect } from "vitest";
import { encodeClaim, hashClaim } from "../src/claim.js";
import type { AgentClaim } from "../src/types.js";
import { parseEther } from "viem";

const GOLDEN_CLAIM: AgentClaim = {
  priceFeed: "0xFB504aD06Ab5E6c63FE0A46FEa245214838E8015",
  claimedPrice: 3_800_000_000n,
  reasoning: "RSI 28.4 < 30 threshold, buy signal",
  action: "BUY_MON",
  protocol: "0x0D97Dc33264bfC1c226207428A79b26757fb9dc3",
  expectedOutputMin: parseEther("260"),
  timestamp: 1747310400n,
  expiry: 1747310460n,
};

const GOLDEN_HASH =
  "0xf20b5a3bd6541968dae39969a2bb95586b9d5f87a670919ad3a30af1e97d3619";

describe("hash-parity", () => {
  it("encodeClaim produces deterministic bytes", () => {
    const a = encodeClaim(GOLDEN_CLAIM);
    const b = encodeClaim(GOLDEN_CLAIM);
    expect(a).toBe(b);
  });

  it("hashClaim matches Solidity golden value (Anayasa #9)", () => {
    const hash = hashClaim(GOLDEN_CLAIM);
    expect(hash).toBe(GOLDEN_HASH);
  });

  it("different claim produces different hash", () => {
    const altered: AgentClaim = { ...GOLDEN_CLAIM, claimedPrice: 999n };
    expect(hashClaim(altered)).not.toBe(GOLDEN_HASH);
  });
});
