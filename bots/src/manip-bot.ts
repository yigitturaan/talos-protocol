import { parseEther, zeroAddress } from "viem";
import {
  generateIntentId,
  hashClaim,
  encodeClaim,
  type AgentClaim,
} from "@talos-protocol/sdk";
import { sdk, publicClient, agentAddress } from "./shared/client.js";
import { CHAINLINK_MON_USD, txLink } from "./shared/config.js";
import { readChainlinkPrice } from "./shared/chainlink.js";
import { createLogger } from "./shared/logger.js";
import { runLoop } from "./shared/loop.js";

const log = createLogger("manip");

async function tick(_signal: AbortSignal) {
  const { price, priceFloat } = await readChainlinkPrice(
    publicClient,
    CHAINLINK_MON_USD,
  );

  log.info(`MON=$${priceFloat.toFixed(4)} — attempting hash manipulation`);

  const repBefore = await sdk.getReputation(agentAddress);
  if (!repBefore) {
    log.warn("Agent not registered. Register with stake first.");
    return;
  }
  const scoreBefore = repBefore.score;
  log.info(`Reputation before: score=${scoreBefore}`);

  const intentId = generateIntentId();
  const now = BigInt(Math.floor(Date.now() / 1000));

  const claimA: AgentClaim = {
    priceFeed: CHAINLINK_MON_USD,
    claimedPrice: price,
    reasoning: "Legitimate trade signal",
    action: "BUY_MON",
    protocol: "0x0d97dc33264bfc1c226207428a79b26757fb9dc3",
    expectedOutputMin: parseEther("1"),
    timestamp: now,
    expiry: now + 300n,
  };

  const claimB: AgentClaim = {
    ...claimA,
    protocol: zeroAddress,
    reasoning: "Swapped claim after commit — should fail hash check",
  };

  const hashA = hashClaim(claimA);
  const hashB = hashClaim(claimB);
  log.info(`Claim A hash=${hashA.slice(0, 18)}...`);
  log.info(`Claim B hash=${hashB.slice(0, 18)}... (different)`);

  try {
    const commitHash = await sdk.commit(intentId, claimA);
    await publicClient.waitForTransactionReceipt({ hash: commitHash });
    log.info(`Committed claim A: ${txLink(commitHash)}`);

    const verifyHash = await sdk.verifyAndExecute(intentId, claimB, []);

    log.warn("Unexpectedly APPROVED — hash mismatch should have been caught!");
    log.warn(`Verify: ${txLink(verifyHash)}`);
    throw new Error("ManipBot assertion failed: expected hash mismatch rejection");
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);

    if (msg.includes("assertion failed")) throw err;

    log.success(`REJECTED (expected): hash mismatch — ${msg}`);

    try {
      const repAfter = await sdk.getReputation(agentAddress);
      if (repAfter) {
        const scoreAfter = repAfter.score;
        log.success(`Reputation after: score=${scoreAfter} (delta=${scoreAfter - scoreBefore})`, {
          hashA: hashA.slice(0, 18),
          hashB: hashB.slice(0, 18),
        });
      }
    } catch {
      log.warn("Could not read post-rejection reputation");
    }
  }
}

async function main() {
  log.info(`Agent: ${agentAddress}`);
  log.info("Starting ManipBot — commits hash A, executes claim B (hash mismatch attack)");

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

  await runLoop("manip", 60_000, tick);
}

main().catch((e: unknown) => {
  const msg = e instanceof Error ? e.message : String(e);
  log.error(msg);
});
