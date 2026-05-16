import {
  type Address,
  type PublicClient,
  type WalletClient,
  type Hash,
  type Log,
  getContract,
  parseEther,
} from "viem";
import { talosProtocolAbi, erc20Abi } from "./abi.js";
import { encodeClaim, hashClaim } from "./claim.js";
import type { AgentClaim, Reputation } from "./types.js";

export interface TalosSDKConfig {
  protocolAddress: Address;
  publicClient: PublicClient;
  walletClient: WalletClient;
}

export class TalosSDK {
  readonly protocolAddress: Address;
  readonly publicClient: PublicClient;
  readonly walletClient: WalletClient;

  constructor(config: TalosSDKConfig) {
    this.protocolAddress = config.protocolAddress;
    this.publicClient = config.publicClient;
    this.walletClient = config.walletClient;
  }

  private get contract() {
    return getContract({
      address: this.protocolAddress,
      abi: talosProtocolAbi,
      client: { public: this.publicClient, wallet: this.walletClient },
    });
  }

  private get account() {
    const acc = this.walletClient.account;
    if (!acc) throw new Error("WalletClient has no account");
    return acc;
  }

  // ═══════════════════════════════════════════════════════
  //  Agent Management
  // ═══════════════════════════════════════════════════════

  async registerAgent(stakeAmount: bigint): Promise<Hash> {
    return this.contract.write.registerAgent([stakeAmount], {
      value: stakeAmount,
      account: this.account,
      chain: this.walletClient.chain,
    });
  }

  // ═══════════════════════════════════════════════════════
  //  Token Approval
  // ═══════════════════════════════════════════════════════

  async approveToken(token: Address, amount: bigint): Promise<Hash> {
    return this.walletClient.writeContract({
      address: token,
      abi: erc20Abi,
      functionName: "approve",
      args: [this.protocolAddress, amount],
      account: this.account,
      chain: this.walletClient.chain,
    });
  }

  // ═══════════════════════════════════════════════════════
  //  Escrow
  // ═══════════════════════════════════════════════════════

  async lockEscrow(
    intentId: `0x${string}`,
    agent: Address,
    token: Address,
    amount: bigint,
    expiry: bigint
  ): Promise<Hash> {
    return this.contract.write.lockEscrow(
      [intentId, agent, token, amount, expiry],
      { account: this.account, chain: this.walletClient.chain }
    );
  }

  async lockEscrowWithPermit(
    intentId: `0x${string}`,
    agent: Address,
    token: Address,
    amount: bigint,
    expiry: bigint,
    deadline: bigint,
    v: number,
    r: `0x${string}`,
    s: `0x${string}`
  ): Promise<Hash> {
    return this.contract.write.lockEscrowWithPermit(
      [intentId, agent, token, amount, expiry, deadline, v, r, s],
      { account: this.account, chain: this.walletClient.chain }
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Commit-Verify-Execute
  // ═══════════════════════════════════════════════════════

  async commit(intentId: `0x${string}`, claim: AgentClaim): Promise<Hash> {
    const claimHash = hashClaim(claim);
    return this.contract.write.commit([intentId, claimHash], {
      account: this.account,
      chain: this.walletClient.chain,
    });
  }

  async verifyAndExecute(
    intentId: `0x${string}`,
    claim: AgentClaim,
    references: Address[]
  ): Promise<Hash> {
    const claimData = encodeClaim(claim);
    return this.contract.write.verifyAndExecute(
      [intentId, claimData, references],
      { account: this.account, chain: this.walletClient.chain }
    );
  }

  async submitAndExecute(
    intentId: `0x${string}`,
    claim: AgentClaim,
    references: Address[]
  ): Promise<{ commitHash: Hash; verifyHash: Hash }> {
    const commitHash = await this.commit(intentId, claim);
    await this.publicClient.waitForTransactionReceipt({ hash: commitHash });

    const verifyHash = await this.verifyAndExecute(
      intentId,
      claim,
      references
    );
    return { commitHash, verifyHash };
  }

  // ═══════════════════════════════════════════════════════
  //  Refund
  // ═══════════════════════════════════════════════════════

  async refund(intentId: `0x${string}`): Promise<Hash> {
    return this.contract.write.refund([intentId], {
      account: this.account,
      chain: this.walletClient.chain,
    });
  }

  // ═══════════════════════════════════════════════════════
  //  Read
  // ═══════════════════════════════════════════════════════

  async getEscrow(intentId: `0x${string}`) {
    return this.contract.read.escrows([intentId]);
  }

  async getReputation(agent: Address) {
    return this.contract.read.reputations([agent]);
  }

  async getVerification(intentId: `0x${string}`) {
    return this.contract.read.verifications([intentId]);
  }

  // ═══════════════════════════════════════════════════════
  //  Event Subscription (WebSocket)
  // ═══════════════════════════════════════════════════════

  onEscrowUpdate(callback: (logs: Log[]) => void): () => void {
    const unwatch = this.publicClient.watchContractEvent({
      address: this.protocolAddress,
      abi: talosProtocolAbi,
      eventName: "EscrowLocked",
      onLogs: callback,
    });
    return unwatch;
  }

  onVerificationPassed(callback: (logs: Log[]) => void): () => void {
    const unwatch = this.publicClient.watchContractEvent({
      address: this.protocolAddress,
      abi: talosProtocolAbi,
      eventName: "VerificationPassed",
      onLogs: callback,
    });
    return unwatch;
  }

  onVerificationFailed(callback: (logs: Log[]) => void): () => void {
    const unwatch = this.publicClient.watchContractEvent({
      address: this.protocolAddress,
      abi: talosProtocolAbi,
      eventName: "VerificationFailed",
      onLogs: callback,
    });
    return unwatch;
  }

  onSoftRejection(callback: (logs: Log[]) => void): () => void {
    const unwatch = this.publicClient.watchContractEvent({
      address: this.protocolAddress,
      abi: talosProtocolAbi,
      eventName: "SoftRejection",
      onLogs: callback,
    });
    return unwatch;
  }
}
