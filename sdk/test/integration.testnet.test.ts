import { describe, it, expect, beforeAll } from "vitest";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  type Address,
  type Hash,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  TalosSDK,
  generateIntentId,
  encodeClaim,
  hashClaim,
  monadTestnet,
  erc20Abi,
} from "../src/index.js";
import type { AgentClaim } from "../src/types.js";
import deployments from "../../deployments/10143.json" with { type: "json" };

const TEST_USDC = "0x148A0E43904e3aF080db4Db18A82609018ecB15e" as Address;

const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`;
if (!PRIVATE_KEY) throw new Error("Set PRIVATE_KEY env var");

const account = privateKeyToAccount(PRIVATE_KEY);
const transport = http("https://testnet-rpc.monad.xyz", {
  retryCount: 3,
  retryDelay: 2_000,
});

const publicClient = createPublicClient({
  chain: monadTestnet,
  transport,
});

const walletClient = createWalletClient({
  account,
  chain: monadTestnet,
  transport,
});

const sdk = new TalosSDK({
  protocolAddress: deployments.TalosProtocol as Address,
  publicClient: publicClient as any,
  walletClient: walletClient as any,
});

async function waitTx(hash: Hash) {
  return publicClient.waitForTransactionReceipt({
    hash,
    timeout: 60_000,
  });
}

function makeClaim(overrides: Partial<AgentClaim> = {}): AgentClaim {
  const now = BigInt(Math.floor(Date.now() / 1000));
  return {
    priceFeed: "0x0000000000000000000000000000000000000000",
    claimedPrice: 1_000_000n,
    reasoning: "integration test",
    action: "TEST",
    protocol: "0x0000000000000000000000000000000000000000",
    expectedOutputMin: 1n,
    timestamp: now,
    expiry: now + 300n,
    ...overrides,
  };
}

describe("SDK Testnet Integration", () => {
  beforeAll(async () => {
    const balance = await publicClient.getBalance({ address: account.address });
    console.log(`Account: ${account.address}`);
    console.log(`Balance: ${balance} wei`);
    expect(balance).toBeGreaterThan(0n);
  });

  it("reads reputation for registered agent", async () => {
    const rep = await sdk.getReputation(account.address);
    expect(rep.agent).toBe(account.address);
    expect(Number(rep.score)).toBe(1000);
    expect(rep.stake).toBe(parseEther("100"));
    expect(rep.isBanned).toBe(false);
    console.log(`Reputation: score=${rep.score}, stake=${rep.stake}`);
  });

  it("approveToken + lockEscrow -> Locked", async () => {
    const intentId = generateIntentId();
    const amount = 50_000_000n; // 50 tUSDC
    const now = BigInt(Math.floor(Date.now() / 1000));
    const expiry = now + 3600n;

    const approveTx = await sdk.approveToken(TEST_USDC, amount);
    await waitTx(approveTx);
    console.log(`approve: ${approveTx}`);

    const lockTx = await sdk.lockEscrow(
      intentId,
      account.address,
      TEST_USDC,
      amount,
      expiry
    );
    await waitTx(lockTx);
    console.log(`lockEscrow: ${lockTx}`);

    const escrow = await sdk.getEscrow(intentId);
    expect(escrow.owner).toBe(account.address);
    expect(escrow.agent).toBe(account.address);
    expect(escrow.amount).toBe(amount);
    expect(Number(escrow.status)).toBe(0); // Locked
    console.log(`Escrow status: Locked (${escrow.status})`);
  });

  it("commit -> Committed", async () => {
    const intentId = generateIntentId();
    const amount = 10_000_000n; // 10 tUSDC
    const now = BigInt(Math.floor(Date.now() / 1000));
    const expiry = now + 3600n;

    const approveTx = await sdk.approveToken(TEST_USDC, amount);
    await waitTx(approveTx);

    const lockTx = await sdk.lockEscrow(
      intentId,
      account.address,
      TEST_USDC,
      amount,
      expiry
    );
    await waitTx(lockTx);

    const claim = makeClaim();
    const commitTx = await sdk.commit(intentId, claim);
    await waitTx(commitTx);
    console.log(`commit: ${commitTx}`);

    const escrow = await sdk.getEscrow(intentId);
    expect(Number(escrow.status)).toBe(1); // Committed
    expect(escrow.commitHash).toBe(hashClaim(claim));
    console.log(`Escrow status: Committed, hash matches`);
  });

  it("verifyAndExecute reverts on testnet (no Chainlink oracle)", async () => {
    const intentId = generateIntentId();
    const amount = 10_000_000n;
    const now = BigInt(Math.floor(Date.now() / 1000));
    const expiry = now + 3600n;

    await waitTx(await sdk.approveToken(TEST_USDC, amount));
    await waitTx(
      await sdk.lockEscrow(
        intentId,
        account.address,
        TEST_USDC,
        amount,
        expiry
      )
    );

    const claim = makeClaim();
    await waitTx(await sdk.commit(intentId, claim));

    // verifyAndExecute requires a live Chainlink feed.
    // On testnet there is none, so the call reverts.
    await expect(
      sdk.verifyAndExecute(intentId, claim, [])
    ).rejects.toThrow();
    console.log("verifyAndExecute correctly reverted (no oracle on testnet)");
  });

  it("refund after expiry -> Expired", async () => {
    const intentId = generateIntentId();
    const amount = 5_000_000n; // 5 tUSDC
    const now = BigInt(Math.floor(Date.now() / 1000));
    const expiry = now + 5n; // 5 seconds

    await waitTx(await sdk.approveToken(TEST_USDC, amount));
    await waitTx(
      await sdk.lockEscrow(
        intentId,
        account.address,
        TEST_USDC,
        amount,
        expiry
      )
    );

    // Wait for expiry
    console.log("Waiting for escrow expiry (~8s)...");
    await new Promise((r) => setTimeout(r, 8_000));

    const refundTx = await sdk.refund(intentId);
    await waitTx(refundTx);
    console.log(`refund: ${refundTx}`);

    const escrow = await sdk.getEscrow(intentId);
    expect(Number(escrow.status)).toBe(5); // Expired
    console.log(`Escrow status: Expired (${escrow.status})`);
  });
});
