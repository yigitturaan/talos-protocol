import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { monadTestnet, monadMainnet } from "@talos-protocol/sdk";

export const config = getDefaultConfig({
  appName: "Talos Terminal",
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || "talos_dev_placeholder",
  chains: [monadTestnet, monadMainnet],
  ssr: true,
});
