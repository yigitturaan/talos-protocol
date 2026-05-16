import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  formatEther,
  parseUnits,
  type Address,
  type Hash,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  TalosSDK,
  monadTestnet,
  generateIntentId,
  hashClaim,
  encodeClaim,
  talosProtocolAbi,
  erc20Abi,
  type AgentClaim,
} from "@talos-protocol/sdk";

// ── Config ──

const PRIVATE_KEY = process.env["PRIVATE_KEY"] as `0x${string}`;
const RPC_URL = process.env["RPC_URL"] || "https://testnet-rpc.monad.xyz";
const EXPLORER = "https://testnet.monadexplorer.com";

const PROTOCOL = "0x4625Ab2d2295f88744dc98379Da80CDC149727e2" as Address;
const DEMO_FEED = "0x470BFcb45f597675d7Dae96286E24E92126D35Ba" as Address;
const TEST_USDC = "0x60bf7859556Ac6834ef6Cf7FcF7c4c64a47F831D" as Address;

const ESCROW_AMOUNT = parseUnits("100", 6); // 100 tUSDC per scenario
const ESCROW_EXPIRY_OFFSET = 3600n; // 1 hour

const transport = http(RPC_URL);
const account = privateKeyToAccount(PRIVATE_KEY);
const publicClient = createPublicClient({ chain: monadTestnet, transport });
const walletClient = createWalletClient({ chain: monadTestnet, transport, account });
const sdk = new TalosSDK({ protocolAddress: PROTOCOL, publicClient, walletClient });
const agent = account.address;

// ── Helpers ──

const C = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
};

function txLink(hash: string) {
  return `${EXPLORER}/tx/${hash}`;
}

function log(prefix: string, msg: string) {
  const ts = new Date().toISOString().slice(11, 19);
  console.log(`${C.dim}${ts}${C.reset} ${prefix} ${msg}`);
}

function header(title: string) {
  console.log(`\n${C.bold}${"═".repeat(60)}${C.reset}`);
  console.log(`${C.bold}  ${title}${C.reset}`);
  console.log(`${C.bold}${"═".repeat(60)}${C.reset}\n`);
}

async function waitTx(hash: Hash) {
  return publicClient.waitForTransactionReceipt({ hash });
}

async function readReputation() {
  const rep = await sdk.getReputation(agent) as any;
  return {
    score: Number(rep.score ?? rep[1]),
    totalVerifications: Number(rep.totalVerifications ?? rep[2]),
    passed: Number(rep.passed ?? rep[3]),
    failed: Number(rep.failed ?? rep[4]),
    stake: rep.stake ?? rep[6],
  };
}

async function approveAndLock(intentId: `0x${string}`) {
  const approveHash = await sdk.approveToken(TEST_USDC, ESCROW_AMOUNT);
  await waitTx(approveHash);

  const expiry = BigInt(Math.floor(Date.now() / 1000)) + ESCROW_EXPIRY_OFFSET;
  const lockHash = await sdk.lockEscrow(intentId, agent, TEST_USDC, ESCROW_AMOUNT, expiry);
  await waitTx(lockHash);
  return lockHash;
}

function makeClaim(overrides: Partial<AgentClaim> & { priceFeed: Address }): AgentClaim {
  const now = BigInt(Math.floor(Date.now() / 1000));
  return {
    priceFeed: overrides.priceFeed,
    claimedPrice: overrides.claimedPrice ?? 50_000_000n, // $0.50, 8 dec
    reasoning: overrides.reasoning ?? "demo",
    action: overrides.action ?? "BUY_MON",
    protocol: overrides.protocol ?? TEST_USDC,
    expectedOutputMin: overrides.expectedOutputMin ?? 1n,
    timestamp: now,
    expiry: now + 300n,
  };
}

const explorerLinks: string[] = [];
const timings: { scenario: string; ms: number }[] = [];

// ── Scenarios ──

async function scenario1_HonestBot() {
  header("SCENARIO 1: HonestBot - Correct Price (PASS)");
  const intentId = generateIntentId();
  const repBefore = await readReputation();
  log(`${C.cyan}[HONEST]${C.reset}`, `Score before: ${repBefore.score}`);

  // Lock escrow
  const lockHash = await approveAndLock(intentId);
  log(`${C.cyan}[HONEST]${C.reset}`, `Escrow locked: ${txLink(lockHash)}`);
  explorerLinks.push(txLink(lockHash));

  // Commit + Verify (measure CVE time)
  const claim = makeClaim({ priceFeed: DEMO_FEED, reasoning: "RSI=28, BUY signal" });
  const t0 = performance.now();

  const commitHash = await sdk.commit(intentId, claim);
  await waitTx(commitHash);
  log(`${C.cyan}[HONEST]${C.reset}`, `Committed: ${txLink(commitHash)}`);
  explorerLinks.push(txLink(commitHash));

  const verifyHash = await sdk.verifyAndExecute(intentId, claim, [DEMO_FEED]);
  await waitTx(verifyHash);
  const elapsed = performance.now() - t0;
  timings.push({ scenario: "HonestBot (PASS)", ms: elapsed });

  log(`${C.green}[HONEST]${C.reset}`, `${C.green}VERIFIED & EXECUTED${C.reset}: ${txLink(verifyHash)}`);
  explorerLinks.push(txLink(verifyHash));

  const repAfter = await readReputation();
  log(`${C.green}[HONEST]${C.reset}`, `Score: ${repBefore.score} -> ${repAfter.score} (CVE: ${elapsed.toFixed(0)}ms)`);
}

async function scenario2_YieldBot() {
  header("SCENARIO 2: YieldBot - Deposit Action (PASS)");
  const intentId = generateIntentId();
  const repBefore = await readReputation();
  log(`${C.cyan}[YIELD]${C.reset}`, `Score before: ${repBefore.score}`);

  const lockHash = await approveAndLock(intentId);
  log(`${C.cyan}[YIELD]${C.reset}`, `Escrow locked: ${txLink(lockHash)}`);
  explorerLinks.push(txLink(lockHash));

  const claim = makeClaim({
    priceFeed: DEMO_FEED,
    action: "DEPOSIT",
    reasoning: "Morpho vault APY=7.2%, above threshold",
  });

  const t0 = performance.now();
  const commitHash = await sdk.commit(intentId, claim);
  await waitTx(commitHash);
  log(`${C.cyan}[YIELD]${C.reset}`, `Committed: ${txLink(commitHash)}`);
  explorerLinks.push(txLink(commitHash));

  const verifyHash = await sdk.verifyAndExecute(intentId, claim, [DEMO_FEED]);
  await waitTx(verifyHash);
  const elapsed = performance.now() - t0;
  timings.push({ scenario: "YieldBot (PASS)", ms: elapsed });

  log(`${C.green}[YIELD]${C.reset}`, `${C.green}VERIFIED & EXECUTED${C.reset}: ${txLink(verifyHash)}`);
  explorerLinks.push(txLink(verifyHash));

  const repAfter = await readReputation();
  log(`${C.green}[YIELD]${C.reset}`, `Score: ${repBefore.score} -> ${repAfter.score} (CVE: ${elapsed.toFixed(0)}ms)`);
}

async function scenario3_SoftReject() {
  header("SCENARIO 3: SoftReject - Price Drift ~3% -> Retry (SOFT REJECT -> PASS)");
  const intentId = generateIntentId();
  const repBefore = await readReputation();
  log(`${C.yellow}[SOFT]${C.reset}`, `Score before: ${repBefore.score}`);

  const lockHash = await approveAndLock(intentId);
  log(`${C.yellow}[SOFT]${C.reset}`, `Escrow locked: ${txLink(lockHash)}`);
  explorerLinks.push(txLink(lockHash));

  // First attempt: 3% off ($0.515 instead of $0.50) => 300 bps > 150 soft, < 500 hard
  const driftyClaim = makeClaim({
    priceFeed: DEMO_FEED,
    claimedPrice: 51_500_000n, // $0.515 = 3% over $0.50
    reasoning: "Network delay caused stale price",
  });

  const t0 = performance.now();
  const commitHash1 = await sdk.commit(intentId, driftyClaim);
  await waitTx(commitHash1);
  log(`${C.yellow}[SOFT]${C.reset}`, `Committed (drifty): ${txLink(commitHash1)}`);
  explorerLinks.push(txLink(commitHash1));

  try {
    const verifyHash = await sdk.verifyAndExecute(intentId, driftyClaim, [DEMO_FEED]);
    await waitTx(verifyHash);
    log(`${C.yellow}[SOFT]${C.reset}`, `Unexpected pass — verify hash: ${txLink(verifyHash)}`);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    log(`${C.yellow}[SOFT]${C.reset}`, `${C.yellow}SOFT REJECTED${C.reset} (expected): ${msg.slice(0, 80)}`);
  }

  const repMid = await readReputation();
  log(`${C.yellow}[SOFT]${C.reset}`, `Score after soft reject: ${repMid.score}`);

  // Retry with correct price
  const correctClaim = makeClaim({
    priceFeed: DEMO_FEED,
    claimedPrice: 50_000_000n,
    reasoning: "Retry with fresh price",
  });

  const commitHash2 = await sdk.commit(intentId, correctClaim);
  await waitTx(commitHash2);
  log(`${C.yellow}[SOFT]${C.reset}`, `Re-committed (correct): ${txLink(commitHash2)}`);
  explorerLinks.push(txLink(commitHash2));

  const verifyHash2 = await sdk.verifyAndExecute(intentId, correctClaim, [DEMO_FEED]);
  await waitTx(verifyHash2);
  const elapsed = performance.now() - t0;
  timings.push({ scenario: "SoftReject->Retry (PASS)", ms: elapsed });

  log(`${C.green}[SOFT]${C.reset}`, `${C.green}RETRY PASSED${C.reset}: ${txLink(verifyHash2)}`);
  explorerLinks.push(txLink(verifyHash2));

  const repAfter = await readReputation();
  log(`${C.green}[SOFT]${C.reset}`, `Score: ${repBefore.score} -> ${repMid.score} -> ${repAfter.score} (total CVE: ${elapsed.toFixed(0)}ms)`);
}

async function scenario4_LiarBot() {
  header("SCENARIO 4: LiarBot - 34% Wrong Price (ORACLE FAIL + SLASH)");
  const intentId = generateIntentId();
  const repBefore = await readReputation();
  log(`${C.red}[LIAR]${C.reset}`, `Score before: ${repBefore.score}, stake: ${formatEther(repBefore.stake)} MON`);

  const lockHash = await approveAndLock(intentId);
  log(`${C.red}[LIAR]${C.reset}`, `Escrow locked: ${txLink(lockHash)}`);
  explorerLinks.push(txLink(lockHash));

  // Claim 34% less than real price ($0.33 vs $0.50)
  const liarClaim = makeClaim({
    priceFeed: DEMO_FEED,
    claimedPrice: 33_000_000n, // $0.33 = 34% under
    reasoning: "Price is low, great buy opportunity",
  });

  const t0 = performance.now();
  const commitHash = await sdk.commit(intentId, liarClaim);
  await waitTx(commitHash);
  log(`${C.red}[LIAR]${C.reset}`, `Committed (liar): ${txLink(commitHash)}`);
  explorerLinks.push(txLink(commitHash));

  try {
    const verifyHash = await sdk.verifyAndExecute(intentId, liarClaim, [DEMO_FEED]);
    await waitTx(verifyHash);
    // If we get here, verification failed on-chain (emitted VerificationFailed)
    const elapsed = performance.now() - t0;
    timings.push({ scenario: "LiarBot (FAIL+SLASH)", ms: elapsed });
    log(`${C.red}[LIAR]${C.reset}`, `${C.red}REJECTED + SLASHED${C.reset}: ${txLink(verifyHash)}`);
    explorerLinks.push(txLink(verifyHash));
  } catch (err: unknown) {
    const elapsed = performance.now() - t0;
    timings.push({ scenario: "LiarBot (FAIL+SLASH)", ms: elapsed });
    const msg = err instanceof Error ? err.message : String(err);
    log(`${C.red}[LIAR]${C.reset}`, `${C.red}REJECTED + SLASHED${C.reset}: ${msg.slice(0, 100)}`);
  }

  const repAfter = await readReputation();
  log(`${C.red}[LIAR]${C.reset}`, `Score: ${repBefore.score} -> ${repAfter.score}, stake: ${formatEther(repBefore.stake)} -> ${formatEther(repAfter.stake)} MON`);
}

async function scenario5_ManipBot() {
  header("SCENARIO 5: ManipBot - Hash Mismatch Attack (HASH FAIL + SLASH)");
  const intentId = generateIntentId();
  const repBefore = await readReputation();
  log(`${C.red}[MANIP]${C.reset}`, `Score before: ${repBefore.score}, stake: ${formatEther(repBefore.stake)} MON`);

  const lockHash = await approveAndLock(intentId);
  log(`${C.red}[MANIP]${C.reset}`, `Escrow locked: ${txLink(lockHash)}`);
  explorerLinks.push(txLink(lockHash));

  // Commit claim A, but try to verify with claim B (different reasoning)
  const claimA = makeClaim({
    priceFeed: DEMO_FEED,
    reasoning: "Legitimate trade signal",
  });
  const claimB = makeClaim({
    priceFeed: DEMO_FEED,
    reasoning: "Swapped claim after commit",
    protocol: "0x0000000000000000000000000000000000000001" as Address,
  });

  log(`${C.red}[MANIP]${C.reset}`, `Hash A: ${hashClaim(claimA).slice(0, 18)}...`);
  log(`${C.red}[MANIP]${C.reset}`, `Hash B: ${hashClaim(claimB).slice(0, 18)}... (different)`);

  const t0 = performance.now();
  const commitHash = await sdk.commit(intentId, claimA);
  await waitTx(commitHash);
  log(`${C.red}[MANIP]${C.reset}`, `Committed claim A: ${txLink(commitHash)}`);
  explorerLinks.push(txLink(commitHash));

  // Verify with claim B (different hash)
  try {
    const verifyHash = await sdk.verifyAndExecute(intentId, claimB, [DEMO_FEED]);
    await waitTx(verifyHash);
    const elapsed = performance.now() - t0;
    timings.push({ scenario: "ManipBot (HASH FAIL)", ms: elapsed });
    log(`${C.red}[MANIP]${C.reset}`, `${C.red}HASH MISMATCH CAUGHT${C.reset}: ${txLink(verifyHash)}`);
    explorerLinks.push(txLink(verifyHash));
  } catch (err: unknown) {
    const elapsed = performance.now() - t0;
    timings.push({ scenario: "ManipBot (HASH FAIL)", ms: elapsed });
    const msg = err instanceof Error ? err.message : String(err);
    log(`${C.red}[MANIP]${C.reset}`, `${C.red}HASH MISMATCH CAUGHT${C.reset}: ${msg.slice(0, 100)}`);
  }

  const repAfter = await readReputation();
  log(`${C.red}[MANIP]${C.reset}`, `Score: ${repBefore.score} -> ${repAfter.score}, stake: ${formatEther(repBefore.stake)} -> ${formatEther(repAfter.stake)} MON`);
}

// ── Main ──

async function main() {
  console.log(`\n${C.bold}╔══════════════════════════════════════════════════════════╗${C.reset}`);
  console.log(`${C.bold}║        TALOS PROTOCOL — JURY DEMO (3 min)               ║${C.reset}`);
  console.log(`${C.bold}║        Monad Testnet (chain 10143)                       ║${C.reset}`);
  console.log(`${C.bold}╚══════════════════════════════════════════════════════════╝${C.reset}\n`);

  log("[INIT]", `Agent: ${agent}`);
  log("[INIT]", `Protocol: ${PROTOCOL}`);
  log("[INIT]", `DemoPriceFeed: ${DEMO_FEED} (MON/USD = $0.50)`);
  log("[INIT]", `Test USDC: ${TEST_USDC}`);

  const initRep = await readReputation();
  log("[INIT]", `Initial score: ${initRep.score}, stake: ${formatEther(initRep.stake)} MON\n`);

  // Run scenarios in order: PASS first (preserve score), FAIL last
  await scenario1_HonestBot();
  await scenario2_YieldBot();
  await scenario3_SoftReject();
  await scenario4_LiarBot();
  await scenario5_ManipBot();

  // ── Summary ──
  header("DEMO SUMMARY");

  const finalRep = await readReputation();
  console.log(`${C.bold}Agent:${C.reset} ${agent}`);
  console.log(`${C.bold}Final Score:${C.reset} ${initRep.score} -> ${finalRep.score}`);
  console.log(`${C.bold}Final Stake:${C.reset} ${formatEther(initRep.stake)} -> ${formatEther(finalRep.stake)} MON`);
  console.log(`${C.bold}Verifications:${C.reset} ${finalRep.totalVerifications} total (${finalRep.passed} passed, ${finalRep.failed} failed)`);

  console.log(`\n${C.bold}CVE Timings:${C.reset}`);
  for (const t of timings) {
    console.log(`  ${t.scenario}: ${t.ms.toFixed(0)}ms`);
  }

  console.log(`\n${C.bold}Explorer Links:${C.reset}`);
  for (const link of explorerLinks) {
    console.log(`  ${link}`);
  }

  console.log(`\n${C.green}${C.bold}Demo complete.${C.reset}\n`);
}

main().catch((e) => {
  console.error(`${C.red}FATAL:${C.reset}`, e instanceof Error ? e.message : e);
  process.exit(1);
});
