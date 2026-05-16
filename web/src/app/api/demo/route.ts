import { NextRequest, NextResponse } from "next/server";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  formatEther,
  formatUnits,
  type Address,
  type Hash,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  TalosSDK,
  monadTestnet,
  generateIntentId,
  hashClaim,
  type AgentClaim,
} from "@talos-protocol/sdk";

const AGENT_KEY = process.env.DEMO_AGENT_KEY as `0x${string}`;
const USER_KEY = process.env.DEMO_USER_KEY as `0x${string}`;

const PROTOCOL = "0x4625Ab2d2295f88744dc98379Da80CDC149727e2" as Address;
const DEMO_FEED = "0x470BFcb45f597675d7Dae96286E24E92126D35Ba" as Address;
const TEST_USDC = "0x60bf7859556Ac6834ef6Cf7FcF7c4c64a47F831D" as Address;
const ESCROW_AMOUNT = parseUnits("100", 6);
const EXPLORER = "https://testnet.monadexplorer.com";

const erc20Abi = [
  {
    type: "function" as const,
    name: "approve" as const,
    inputs: [
      { name: "spender", type: "address" as const },
      { name: "amount", type: "uint256" as const },
    ],
    outputs: [{ name: "", type: "bool" as const }],
    stateMutability: "nonpayable" as const,
  },
  {
    type: "function" as const,
    name: "balanceOf" as const,
    inputs: [{ name: "account", type: "address" as const }],
    outputs: [{ name: "", type: "uint256" as const }],
    stateMutability: "view" as const,
  },
] as const;

const setPriceAbi = [
  {
    type: "function" as const,
    name: "setPrice" as const,
    inputs: [{ name: "newPrice", type: "int256" as const }],
    outputs: [],
    stateMutability: "nonpayable" as const,
  },
] as const;

type BotType = "honest" | "yield" | "liar" | "manip";

export async function POST(req: NextRequest) {
  const { bot } = (await req.json()) as { bot: BotType };

  if (!AGENT_KEY || !USER_KEY) {
    return NextResponse.json({ error: "Keys not configured" }, { status: 500 });
  }

  if (!["honest", "yield", "liar", "manip"].includes(bot)) {
    return NextResponse.json({ error: "Invalid bot type" }, { status: 400 });
  }

  const agentAccount = privateKeyToAccount(AGENT_KEY);
  const userAccount = privateKeyToAccount(USER_KEY);
  const transport = http("https://testnet-rpc.monad.xyz");
  const publicClient = createPublicClient({ chain: monadTestnet, transport });

  const agentWallet = createWalletClient({ chain: monadTestnet, transport, account: agentAccount });
  const userWallet = createWalletClient({ chain: monadTestnet, transport, account: userAccount });

  const agentSdk = new TalosSDK({ protocolAddress: PROTOCOL, publicClient, walletClient: agentWallet });

  const agentAddr = agentAccount.address;
  const userAddr = userAccount.address;

  try {
    // Refresh DemoPriceFeed timestamp to avoid StaleOracleData
    await agentWallet.writeContract({
      address: DEMO_FEED,
      abi: setPriceAbi,
      functionName: "setPrice",
      args: [50_000_000n],
      account: agentAccount,
      chain: monadTestnet,
    });

    // Read agent reputation before
    const repBefore = (await agentSdk.getReputation(agentAddr)) as any;
    const scoreBefore = Number(repBefore.score ?? repBefore[1]);
    const stakeBefore = repBefore.stake ?? repBefore[6];

    // Read user tUSDC balance before
    const userBalBefore = (await publicClient.readContract({
      address: TEST_USDC,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [userAddr],
    })) as bigint;

    const intentId = generateIntentId();
    const now = BigInt(Math.floor(Date.now() / 1000));
    const expiry = now + 3600n;

    // ═══ STEP 1: USER locks escrow ═══
    // User approves protocol to spend tUSDC
    const approveHash = await userWallet.writeContract({
      address: TEST_USDC,
      abi: erc20Abi,
      functionName: "approve",
      args: [PROTOCOL, ESCROW_AMOUNT],
      account: userAccount,
      chain: monadTestnet,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });

    // User locks escrow for this agent
    const userSdk = new TalosSDK({ protocolAddress: PROTOCOL, publicClient, walletClient: userWallet });
    const lockHash = await userSdk.lockEscrow(intentId, agentAddr, TEST_USDC, ESCROW_AMOUNT, expiry);
    await publicClient.waitForTransactionReceipt({ hash: lockHash });

    // ═══ STEP 2: AGENT commits claim ═══
    let claim: AgentClaim;
    let claimForVerify: AgentClaim;

    switch (bot) {
      case "honest":
        claim = {
          priceFeed: DEMO_FEED,
          claimedPrice: 50_000_000n,
          reasoning: "RSI=28, BUY signal - correct price",
          action: "BUY_MON",
          protocol: TEST_USDC,
          expectedOutputMin: 1n,
          timestamp: now,
          expiry: now + 300n,
        };
        claimForVerify = claim;
        break;
      case "yield":
        claim = {
          priceFeed: DEMO_FEED,
          claimedPrice: 50_000_000n,
          reasoning: "Morpho vault APY=7.2%, above threshold",
          action: "DEPOSIT",
          protocol: TEST_USDC,
          expectedOutputMin: 1n,
          timestamp: now,
          expiry: now + 300n,
        };
        claimForVerify = claim;
        break;
      case "liar":
        claim = {
          priceFeed: DEMO_FEED,
          claimedPrice: 33_000_000n,
          reasoning: "Price is low, great buy (LIE - real is $0.50)",
          action: "BUY_MON",
          protocol: TEST_USDC,
          expectedOutputMin: 1n,
          timestamp: now,
          expiry: now + 300n,
        };
        claimForVerify = claim;
        break;
      case "manip":
        claim = {
          priceFeed: DEMO_FEED,
          claimedPrice: 50_000_000n,
          reasoning: "Legitimate trade signal",
          action: "BUY_MON",
          protocol: TEST_USDC,
          expectedOutputMin: 1n,
          timestamp: now,
          expiry: now + 300n,
        };
        claimForVerify = {
          ...claim,
          reasoning: "Swapped claim post-commit (MANIPULATION)",
          protocol: "0x0000000000000000000000000000000000000001" as Address,
        };
        break;
    }

    const commitHash = await agentSdk.commit(intentId, claim);
    await publicClient.waitForTransactionReceipt({ hash: commitHash });

    // ═══ STEP 3: AGENT calls verifyAndExecute ═══
    let verifyHash: string | null = null;
    let passed = false;

    try {
      const hash = await agentSdk.verifyAndExecute(intentId, claimForVerify, [DEMO_FEED]);
      await publicClient.waitForTransactionReceipt({ hash });
      verifyHash = hash;
      passed = bot === "honest" || bot === "yield";
    } catch {
      passed = false;
    }

    // ═══ Read final state ═══
    const repAfter = (await agentSdk.getReputation(agentAddr)) as any;
    const scoreAfter = Number(repAfter.score ?? repAfter[1]);
    const stakeAfter = repAfter.stake ?? repAfter[6];

    const userBalAfter = (await publicClient.readContract({
      address: TEST_USDC,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [userAddr],
    })) as bigint;

    return NextResponse.json({
      success: true,
      bot,
      passed,
      user: {
        address: userAddr,
        balanceBefore: formatUnits(userBalBefore, 6),
        balanceAfter: formatUnits(userBalAfter, 6),
      },
      agent: {
        address: agentAddr,
        scoreBefore,
        scoreAfter,
        stakeBefore: formatEther(stakeBefore),
        stakeAfter: formatEther(stakeAfter),
      },
      txs: {
        lock: `${EXPLORER}/tx/${lockHash}`,
        commit: `${EXPLORER}/tx/${commitHash}`,
        verify: verifyHash ? `${EXPLORER}/tx/${verifyHash}` : null,
      },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: msg.slice(0, 200) }, { status: 500 });
  }
}
