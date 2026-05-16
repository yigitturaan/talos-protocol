import { parseEther } from "viem";
import {
  generateIntentId,
  hashClaim,
  type AgentClaim,
} from "@talos-protocol/sdk";
import { sdk, publicClient, agentAddress } from "./shared/client.js";
import { CHAINLINK_MON_USD, txLink } from "./shared/config.js";
import { readChainlinkPrice, calculateRSI } from "./shared/chainlink.js";
import { createLogger } from "./shared/logger.js";
import { runLoop } from "./shared/loop.js";

const log = createLogger("honest");
const priceHistory: number[] = [];

async function tick(_signal: AbortSignal) {
  const { price, priceFloat } = await readChainlinkPrice(
    publicClient,
    CHAINLINK_MON_USD,
  );
  priceHistory.push(priceFloat);
  if (priceHistory.length > 20) priceHistory.shift();

  const rsi = calculateRSI(priceHistory);
  log.info(`MON=$${priceFloat.toFixed(4)} RSI=${rsi.toFixed(1)}`);

  let action: string;
  if (rsi < 30) action = "BUY_MON";
  else if (rsi > 70) action = "SELL_MON";
  else {
    log.info("RSI neutral — no trade signal");
    return;
  }

  const reputation = await sdk.getReputation(agentAddress);
  if (!reputation) {
    log.warn("Agent not registered. Register with stake first.");
    return;
  }
  log.info(`Reputation: score=${reputation.score}, stake=${reputation.stake}`);

  const intentId = generateIntentId();
  const now = BigInt(Math.floor(Date.now() / 1000));

  const claim: AgentClaim = {
    priceFeed: CHAINLINK_MON_USD,
    claimedPrice: price,
    reasoning: `RSI=${rsi.toFixed(0)}, MON=$${priceFloat.toFixed(4)}, honest signal`,
    action,
    protocol: "0x0d97dc33264bfc1c226207428a79b26757fb9dc3",
    expectedOutputMin: parseEther("1"),
    timestamp: now,
    expiry: now + 300n,
  };

  const claimHash = hashClaim(claim);
  log.info(`Claim: ${action} | hash=${claimHash.slice(0, 18)}...`);

  try {
    const { commitHash, verifyHash } = await sdk.submitAndExecute(
      intentId,
      claim,
      [],
    );

    log.success(`Committed: ${txLink(commitHash)}`);
    log.success(`Verified & Executed: ${txLink(verifyHash)}`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    log.error(`TX failed: ${msg}`);
  }
}

async function main() {
  log.info(`Agent: ${agentAddress}`);
  log.info("Starting HonestBot — real Chainlink prices, honest claims");

  try {
    const rep = await sdk.getReputation(agentAddress);
    if (rep) {
      log.info(`Reputation loaded: score=${rep.score}, verifications=${rep.totalVerifications}`);
    } else {
      log.warn("Agent not registered on protocol yet");
    }
  } catch {
    log.warn("Could not read reputation — protocol may not be deployed");
  }

  await runLoop("honest", 30_000, tick);
}

main().catch((e: unknown) => {
  const msg = e instanceof Error ? e.message : String(e);
  log.error(msg);
});
