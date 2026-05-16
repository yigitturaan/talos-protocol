import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  parseUnits,
  formatEther,
  formatUnits,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { monadTestnet } from "@talos-protocol/sdk";

const transferAbi = [
  {
    type: "function",
    name: "transfer",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;

const BOT_KEY = process.env["PRIVATE_KEY"] as `0x${string}`;
const USER_ADDR = "0x83D1B3ed570270F2d7E80AA561d64Bf69580dFf3" as const;
const TEST_USDC = "0x60bf7859556Ac6834ef6Cf7FcF7c4c64a47F831D" as const;

const account = privateKeyToAccount(BOT_KEY);
const transport = http("https://testnet-rpc.monad.xyz");
const publicClient = createPublicClient({ chain: monadTestnet, transport });
const walletClient = createWalletClient({ chain: monadTestnet, transport, account });

async function fund() {
  console.log("Bot wallet:", account.address);
  console.log("User wallet:", USER_ADDR);
  console.log("---");

  // Send 5 MON for gas
  const monHash = await walletClient.sendTransaction({
    to: USER_ADDR,
    value: parseEther("5"),
    chain: monadTestnet,
    account,
  });
  console.log("MON transfer tx:", monHash);
  await publicClient.waitForTransactionReceipt({ hash: monHash });

  // Send 1000 tUSDC
  const usdcHash = await walletClient.writeContract({
    address: TEST_USDC,
    abi: transferAbi,
    functionName: "transfer",
    args: [USER_ADDR, parseUnits("1000", 6)],
    chain: monadTestnet,
    account,
  });
  console.log("tUSDC transfer tx:", usdcHash);
  await publicClient.waitForTransactionReceipt({ hash: usdcHash });

  // Check final balances
  const monBal = await publicClient.getBalance({ address: USER_ADDR });
  const usdcBal = await publicClient.readContract({
    address: TEST_USDC,
    abi: transferAbi,
    functionName: "balanceOf",
    args: [USER_ADDR],
  });
  console.log("---");
  console.log("User MON balance:", formatEther(monBal));
  console.log("User tUSDC balance:", formatUnits(usdcBal as bigint, 6));
  console.log("User wallet funded!");
}

fund().catch((e) => {
  console.error("Error:", e instanceof Error ? e.message : e);
  process.exit(1);
});
