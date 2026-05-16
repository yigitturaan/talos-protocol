import {
  createPublicClient,
  createWalletClient,
  http,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { TalosSDK, monadTestnet } from "@talos-protocol/sdk";
import { PRIVATE_KEY, TALOS_PROTOCOL_ADDRESS, RPC_URL } from "./config.js";

const transport = http(RPC_URL);
const account = privateKeyToAccount(PRIVATE_KEY);

export const publicClient = createPublicClient({
  chain: monadTestnet,
  transport,
});

export const walletClient = createWalletClient({
  chain: monadTestnet,
  transport,
  account,
});

export const sdk = new TalosSDK({
  protocolAddress: TALOS_PROTOCOL_ADDRESS,
  publicClient,
  walletClient,
});

export const agentAddress = account.address;
