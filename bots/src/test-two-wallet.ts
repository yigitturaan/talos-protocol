import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  formatEther,
  type Address,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  TalosSDK,
  monadTestnet,
  generateIntentId,
  type AgentClaim,
} from "@talos-protocol/sdk";

const AGENT_KEY = "0x9ba851f0e49e6c5ad0fdc14220ae3d87e9134d85523e2def7f82425d2d357982" as const;
const USER_KEY = "0x0fe125291980f9a9cabb6ae218a962abda11d3f6c21879747114fad9d1633a5e" as const;
const PROTOCOL = "0x4625Ab2d2295f88744dc98379Da80CDC149727e2" as Address;
const DEMO_FEED = "0x470BFcb45f597675d7Dae96286E24E92126D35Ba" as Address;
const TEST_USDC = "0x60bf7859556Ac6834ef6Cf7FcF7c4c64a47F831D" as Address;
const ESCROW = parseUnits("100", 6);

const agentAccount = privateKeyToAccount(AGENT_KEY);
const userAccount = privateKeyToAccount(USER_KEY);
const transport = http("https://testnet-rpc.monad.xyz");
const publicClient = createPublicClient({ chain: monadTestnet, transport });
const agentWallet = createWalletClient({ chain: monadTestnet, transport, account: agentAccount });
const userWallet = createWalletClient({ chain: monadTestnet, transport, account: userAccount });

const agentSdk = new TalosSDK({ protocolAddress: PROTOCOL, publicClient, walletClient: agentWallet });
const userSdk = new TalosSDK({ protocolAddress: PROTOCOL, publicClient, walletClient: userWallet });

async function test() {
  const intentId = generateIntentId();
  const now = BigInt(Math.floor(Date.now() / 1000));

  console.log("Agent:", agentAccount.address);
  console.log("User:", userAccount.address);
  console.log("---");

  // User approves + locks escrow
  console.log("1. User approving tUSDC...");
  const ah = await userSdk.approveToken(TEST_USDC, ESCROW);
  await publicClient.waitForTransactionReceipt({ hash: ah });
  console.log("   Approved!");

  console.log("2. User locking escrow for agent...");
  try {
    const lh = await userSdk.lockEscrow(intentId, agentAccount.address, TEST_USDC, ESCROW, now + 3600n);
    await publicClient.waitForTransactionReceipt({ hash: lh });
    console.log("   Escrow locked!");
  } catch (e: any) {
    console.error("   LOCK FAILED:", e.shortMessage || e.message?.slice(0, 200));
    return;
  }

  // Agent commits
  const claim: AgentClaim = {
    priceFeed: DEMO_FEED,
    claimedPrice: 50_000_000n,
    reasoning: "RSI=28 BUY signal",
    action: "BUY_MON",
    protocol: TEST_USDC,
    expectedOutputMin: 1n,
    timestamp: now,
    expiry: now + 300n,
  };

  console.log("3. Agent committing claim...");
  try {
    const ch = await agentSdk.commit(intentId, claim);
    await publicClient.waitForTransactionReceipt({ hash: ch });
    console.log("   Commit OK!");
  } catch (e: any) {
    console.error("   COMMIT FAILED:", e.shortMessage || e.message?.slice(0, 200));
    return;
  }

  console.log("4. Agent verifyAndExecute...");
  try {
    const vh = await agentSdk.verifyAndExecute(intentId, claim, [DEMO_FEED]);
    const receipt = await publicClient.waitForTransactionReceipt({ hash: vh });
    console.log("   Verify OK! Status:", receipt.status);
  } catch (e: any) {
    console.error("   VERIFY FAILED:", e.shortMessage || e.message?.slice(0, 200));
  }
}

test().catch((e) => console.error("FATAL:", e.message));
