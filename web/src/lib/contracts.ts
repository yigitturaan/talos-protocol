import { talosProtocolAbi } from "@talos-protocol/sdk";
import type { Address } from "viem";

export const TALOS_PROTOCOL_ADDRESS: Address =
  "0x4625Ab2d2295f88744dc98379Da80CDC149727e2";

export const protocolConfig = {
  address: TALOS_PROTOCOL_ADDRESS,
  abi: talosProtocolAbi,
} as const;
