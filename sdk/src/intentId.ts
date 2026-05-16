import { bytesToHex } from "viem";

declare const crypto: {
  getRandomValues<T extends ArrayBufferView>(array: T): T;
};

export function generateIntentId(): `0x${string}` {
  return bytesToHex(crypto.getRandomValues(new Uint8Array(16)));
}
