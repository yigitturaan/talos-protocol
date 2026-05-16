import { parseEther } from "viem";
import {
  generateIntentId,
  hashClaim,
  type AgentClaim,
} from "@talos-protocol/sdk";
import { sdk, publicClient, agentAddress } from "./shared/client.js";
import { CHAINLINK_MON_USD, MORPHO_VAULT, txLink } from "./shared/config.js";
import { readChainlinkPrice } from "./shared/chainlink.js";
import {
  readVaultSnapshot,
  estimateAPY,
  type VaultSnapshot,
} from "./shared/morpho.js";
import { createLogger } from "./shared/logger.js";
import { runLoop } from "./shared/loop.js";

const log = createLogger("yield");
const APY_THRESHOLD = 5.0;
let previousSnapshot: VaultSnapshot | null = null;

async function tick(_signal: AbortSignal) {
  if (!MORPHO_VAULT) {
    log.warn("MORPHO_VAULT not set in .env — skipping");
    return;
  }

  const [priceData, snapshot] = await Promise.all([
    readChainlinkPrice(publicClient, CHAINLINK_MON_USD),
    readVaultSnapshot(publicClient, MORPHO_VAULT),
  ]);

  let apy = 0;
  if (previousSnapshot) {
    apy = estimateAPY(previousSnapshot, snapshot);
  }
  previousSnapshot = snapshot;

  log.info(
    `Vault TVL=${(Number(snapshot.totalAssets) / 1e18).toFixed(2)} | ` +
    `Share price=${(Number(snapshot.sharePriceRaw) / 1e18).toFixed(6)} | ` +
    `APY≈${apy.toFixed(2)}% | MON=$${priceData.priceFloat.toFixed(4)}`,
  );

  if (apy < APY_THRESHOLD) {
    log.info(`APY ${apy.toFixed(2)}% below ${APY_THRESHOLD}% threshold — skipping deposit`);
    return;
  }

  const reputation = await sdk.getReputation(agentAddress);
  if (!reputation) {
    log.warn("Agent not registered. Register with stake first.");
    return;
  }

  const intentId = generateIntentId();
  const now = BigInt(Math.floor(Date.now() / 1000));

  const claim: AgentClaim = {
    priceFeed: CHAINLINK_MON_USD,
    claimedPrice: priceData.price,
    reasoning: `Morpho vault APY=${apy.toFixed(2)}%, above ${APY_THRESHOLD}% threshold`,
    action: "DEPOSIT",
    protocol: MORPHO_VAULT,
    expectedOutputMin: parseEther("1"),
    timestamp: now,
    expiry: now + 300n,
  };

  const claimHash = hashClaim(claim);
  log.info(`Claim: DEPOSIT | hash=${claimHash.slice(0, 18)}...`);

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
  log.info("Starting YieldBot — monitors Morpho vault APY, deposits when >5%");

  if (!MORPHO_VAULT) {
    log.error("MORPHO_VAULT env var not set. Set it in .env and restart.");
    process.exit(1);
  }

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

  await runLoop("yield", 60_000, tick);
}

main().catch((e: unknown) => {
  const msg = e instanceof Error ? e.message : String(e);
  log.error(msg);
});
