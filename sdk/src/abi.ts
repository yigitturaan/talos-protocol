export const talosProtocolAbi = [
  // registerAgent
  {
    type: "function",
    name: "registerAgent",
    inputs: [{ name: "stakeAmount", type: "uint256" }],
    outputs: [],
    stateMutability: "payable",
  },
  // lockEscrow
  {
    type: "function",
    name: "lockEscrow",
    inputs: [
      { name: "intentId", type: "bytes16" },
      { name: "agent", type: "address" },
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "expiry", type: "uint64" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // lockEscrowWithPermit
  {
    type: "function",
    name: "lockEscrowWithPermit",
    inputs: [
      { name: "intentId", type: "bytes16" },
      { name: "agent", type: "address" },
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "expiry", type: "uint64" },
      { name: "deadline", type: "uint256" },
      { name: "v", type: "uint8" },
      { name: "r", type: "bytes32" },
      { name: "s", type: "bytes32" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // commit
  {
    type: "function",
    name: "commit",
    inputs: [
      { name: "intentId", type: "bytes16" },
      { name: "claimHash", type: "bytes32" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // verifyAndExecute
  {
    type: "function",
    name: "verifyAndExecute",
    inputs: [
      { name: "intentId", type: "bytes16" },
      { name: "claimData", type: "bytes" },
      { name: "references", type: "address[]" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // refund
  {
    type: "function",
    name: "refund",
    inputs: [{ name: "intentId", type: "bytes16" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // adjustPolicy
  {
    type: "function",
    name: "adjustPolicy",
    inputs: [
      { name: "escrowId", type: "bytes16" },
      { name: "newDailyLimit", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // escrows (view)
  {
    type: "function",
    name: "escrows",
    inputs: [{ name: "intentId", type: "bytes16" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "intentId", type: "bytes16" },
          { name: "owner", type: "address" },
          { name: "agent", type: "address" },
          { name: "token", type: "address" },
          { name: "amount", type: "uint256" },
          { name: "createdAt", type: "uint64" },
          { name: "expiry", type: "uint64" },
          { name: "status", type: "uint8" },
          { name: "commitHash", type: "bytes32" },
          { name: "verified", type: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  // reputations (view)
  {
    type: "function",
    name: "reputations",
    inputs: [{ name: "agent", type: "address" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "agent", type: "address" },
          { name: "score", type: "uint16" },
          { name: "totalVerifications", type: "uint32" },
          { name: "passed", type: "uint32" },
          { name: "failed", type: "uint32" },
          { name: "totalVolume", type: "uint256" },
          { name: "stake", type: "uint256" },
          { name: "registeredAt", type: "uint64" },
          { name: "lastVerified", type: "uint64" },
          { name: "isBanned", type: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  // verifications (view)
  {
    type: "function",
    name: "verifications",
    inputs: [{ name: "intentId", type: "bytes16" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "intentId", type: "bytes16" },
          { name: "agent", type: "address" },
          { name: "decision", type: "uint8" },
          { name: "hashMatched", type: "bool" },
          { name: "oracleMatched", type: "bool" },
          { name: "policyPassed", type: "bool" },
          { name: "failureCode", type: "uint8" },
          { name: "claimedPrice", type: "uint256" },
          { name: "oraclePrice", type: "uint256" },
          { name: "priceDeviationBps", type: "uint16" },
          { name: "verifiedAt", type: "uint64" },
        ],
      },
    ],
    stateMutability: "view",
  },
  // Events
  {
    type: "event",
    name: "AgentRegistered",
    inputs: [
      { name: "agent", type: "address", indexed: true },
      { name: "stakeAmount", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "EscrowLocked",
    inputs: [
      { name: "intentId", type: "bytes16", indexed: true },
      { name: "owner", type: "address", indexed: true },
      { name: "agent", type: "address", indexed: true },
      { name: "token", type: "address", indexed: false },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "ClaimCommitted",
    inputs: [
      { name: "intentId", type: "bytes16", indexed: true },
      { name: "agent", type: "address", indexed: true },
      { name: "claimHash", type: "bytes32", indexed: false },
    ],
  },
  {
    type: "event",
    name: "VerificationPassed",
    inputs: [
      { name: "intentId", type: "bytes16", indexed: true },
      { name: "agent", type: "address", indexed: true },
    ],
  },
  {
    type: "event",
    name: "VerificationFailed",
    inputs: [
      { name: "intentId", type: "bytes16", indexed: true },
      { name: "agent", type: "address", indexed: true },
      { name: "failureCode", type: "uint8", indexed: false },
    ],
  },
  {
    type: "event",
    name: "SoftRejection",
    inputs: [
      { name: "intentId", type: "bytes16", indexed: true },
      { name: "deviationBps", type: "uint16", indexed: false },
    ],
  },
  {
    type: "event",
    name: "EscrowRefunded",
    inputs: [
      { name: "intentId", type: "bytes16", indexed: true },
      { name: "owner", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "AgentSlashed",
    inputs: [
      { name: "agent", type: "address", indexed: true },
      { name: "slashAmount", type: "uint256", indexed: false },
    ],
  },
] as const;

export const erc20Abi = [
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
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
