import { parseEther } from "viem";
import {
  generateIntentId,
  hashClaim,
  type AgentClaim,
} from "@talos-protocol/sdk";
import { sdk, publicClient, agentAddress } from "./shared/client.js";
import { CHAINLINK_MON_USD, txLink } from "./shared/config.js";
import { readChainlinkPrice } from "./shared/chainlink.js";
import { createLogger } from "./shared/logger.js";
import { runLoop } from "./shared/loop.js";

const log = createLogger("liar");
const DEVIATION_FACTOR = 66n; // claim %34 lower than real → HardReject

async function tick(_signal: AbortSignal) {
  const { price: realPrice, priceFloat: realFloat } = await readChainlinkPrice(
    publicClient,
    CHAINLINK_MON_USD,
  );

  const liarPrice = (realPrice * DEVIATION_FACTOR) / 100n;
  const liarFloat = Number(liarPrice) / 10 ** 8;

  log.info(
    `Real=$${realFloat.toFixed(4)} Claimed=$${liarFloat.toFixed(4)} (34% under)`,
  );

  const repBefore = await sdk.getReputation(agentAddress);
  if (!repBefore) {
    log.warn("Agent not registered. Register with stake first.");
    return;
  }
  const scoreBefore = repBefore.score;
  log.info(`Reputation before: score=${scoreBefore}`);

  const intentId = generateIntentId();
  const now = BigInt(Math.floor(Date.now() / 1000));

  const claim: AgentClaim = {
    priceFeed: CHAINLINK_MON_USD,
    claimedPrice: liarPrice,
    reasoning: "Price is low, great buy opportunity",
    action: "BUY_MON",
    protocol: "0x0d97dc33264bfc1c226207428a79b26757fb9dc3",
    expectedOutputMin: parseEther("1"),
    timestamp: now,
    expiry: now + 300n,
  };

  const claimHash = hashClaim(claim);
  log.info(`Liar claim hash=${claimHash.slice(0, 18)}...`);

  try {
    const { commitHash, verifyHash } = await sdk.submitAndExecute(
      intentId,
      claim,
      [],
    );

    log.warn("Unexpectedly APPROVED — this should have been rejected!");
    log.warn(`Commit: ${txLink(commitHash)}`);
    log.warn(`Verify: ${txLink(verifyHash)}`);
    throw new Error("LiarBot assertion failed: expected HardReject but got Executed");
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);

    if (msg.includes("assertion failed")) throw err;

    log.success(`REJECTED (expected): ${msg}`);

    try {
      const repAfter = await sdk.getReputation(agentAddress);
      if (repAfter) {
        const scoreAfter = repAfter.score;
        log.success(`Reputation after: score=${scoreAfter} (delta=${scoreAfter - scoreBefore})`, {
          realPrice: realFloat,
          claimedPrice: liarFloat,
          deviation: "34%",
        });
      }
    } catch {
      log.warn("Could not read post-rejection reputation");
    }
  }
}

async function main() {
  log.info(`Agent: ${agentAddress}`);
  log.info("Starting LiarBot — intentionally wrong prices (34% deviation)");

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

  await runLoop("liar", 45_000, tick);
}

main().catch((e: unknown) => {
  const msg = e instanceof Error ? e.message : String(e);
  log.error(msg);
});
