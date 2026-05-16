# TALOS Protocol

**Pre-Trade Claim Verification & Escrow Protection for Autonomous AI Agents on Monad**

> Built for Canakkale Monad Blitz Hackathon 2026

---

## The Problem

AI trading agents are being deployed with direct access to user funds. They hallucinate data, manipulate prices, overspend budgets, and interact with unverified contracts — all while users have zero visibility or control over what happens between "I approve" and "my money is gone."

Current DeFi infrastructure assumes human operators. When an autonomous agent claims "MON price is $2.50, great buy opportunity" — there is no mechanism to verify that claim before the trade executes. If the agent is wrong (or lying), the user loses funds with no recourse.

---

## The Solution

Talos introduces an on-chain **Commit-Verify-Execute (CVE)** gate between AI agents and user funds:

```
Agent claims "MON = $2.50, BUY signal"
        │
        ▼
┌─────────────────────────┐
│  1. COMMIT (hash lock)   │  Agent commits claim hash — can't change after
├─────────────────────────┤
│  2. VERIFY               │  3-layer verification against live data:
│     • Hash integrity     │    - Does the claim match the commitment?
│     • Oracle accuracy    │    - Does the price match Chainlink feed?
│     • Policy compliance  │    - Within spending/slippage/drawdown limits?
├─────────────────────────┤
│  3. EXECUTE              │  Only if ALL checks pass
└─────────────────────────┘
        │
   ✓ PASS → Escrow released → Trade executes
   ✗ FAIL → Funds refunded to user → Agent stake slashed
```

**Key guarantee:** User funds are locked in escrow and *never* directly accessible by the agent. If verification fails for any reason, funds are automatically returned. The agent can never run away with user money.

---

## Why Monad?

Talos is built specifically for Monad's architecture:

| Feature | Why It Matters |
|---|---|
| **400ms block time** | Full CVE flow (3 on-chain txs) completes in ~2 seconds |
| **Deferred Execution** | Monad's N-2 state lag means you can't trust "current" state — escrow neutralizes this risk |
| **High throughput** | Thousands of agent verifications per second without congestion |
| **EVM compatibility** | Leverages existing Chainlink, Uniswap V4, and OpenZeppelin infrastructure |

---

## Architecture

```
talos/
├── contracts/          Foundry — Solidity 0.8.28 (Cancun EVM)
│   ├── src/
│   │   ├── TalosProtocol.sol       Core: commit, verify, execute, escrow
│   │   ├── verifiers/              PriceVerifier, BalanceVerifier, StateVerifier
│   │   ├── policies/               SpendingLimit, ContractWhitelist, SlippageGuard, Drawdown
│   │   ├── execution/              UniswapV4Adapter, MorphoAdapter
│   │   ├── libraries/              ClaimEncoder, ReputationLib
│   │   └── demo/                   DemoPriceFeed, DemoSwapAdapter, DemoDepositAdapter
│   └── test/                       Fork tests (Monad mainnet state)
├── sdk/                @talos-protocol/sdk — TypeScript
│   └── src/            TalosSDK class, ClaimEncoder (hash parity), chain defs
├── bots/               Demo bots — HonestBot, YieldBot, LiarBot, ManipBot
│   └── src/demo.ts     Full 5-scenario end-to-end demo script
├── web/                Talos Terminal — Next.js 15 + wagmi + RainbowKit
│   ├── src/app/        Landing page + /demo route
│   └── src/components/ DemoPanel, VerificationFeed, ReputationLeaderboard
├── deployments/        Deployed contract addresses per chain
└── addresses.json      Canonical external addresses (Chainlink, Uniswap, Morpho)
```

---

## How Verification Works

### 3-Layer System

| Layer | What It Checks | Failure Mode |
|---|---|---|
| **Hash Integrity** | Agent's claim at verify-time matches the committed hash | Instant reject + slash (tampering detected) |
| **Oracle Accuracy** | Claimed price vs. Chainlink feed within tolerance | Tiered: soft reject (1.5%) allows retry, hard reject (5%+) slashes |
| **Policy Compliance** | Spending limits, slippage guards, drawdown circuit breaker, contract whitelist | Reject + slash based on severity |

### Tiered Tolerance

| Threshold | Meaning | Action |
|---|---|---|
| < 1.5% deviation | Network delay margin | PASS |
| 1.5% – 5% deviation | Suspicious but not malicious | SOFT REJECT — retry allowed |
| > 5% deviation | Clearly wrong/malicious | HARD REJECT — stake slashed |
| > 10% market drop | Circuit breaker | ALL trades halted |

### Dual Penalty System

Failed verification triggers two consequences:
1. **Reputation score decrease** — ELO-style score (starts at 1000, ban at 100)
2. **Stake slash** — 10% of agent's staked MON is burned

This creates strong economic incentives for agents to be honest.

---

## Escrow Model

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│    USER     │──lock──▶│   ESCROW     │──release─▶│   TRADE     │
│             │◀─refund─│  (per-intent)│           │  (swap/dep) │
└─────────────┘         └──────────────┘         └─────────────┘
                              │
                         Agent NEVER
                         touches funds
                         directly
```

- Funds locked per-intent with a specific agent and expiry
- Released only on successful verification
- Automatically refunded if verification fails or intent expires
- Agent has zero direct access to escrow funds

---

## Testnet Deployment (Monad Testnet — Chain 10143)

| Contract | Address |
|---|---|
| **TalosProtocol** | `0x4625Ab2d2295f88744dc98379Da80CDC149727e2` |
| PriceVerifier | `0xdad43045101411d707E0df3638E6E31d1392465E` |
| BalanceVerifier | `0x3Bb7EE264aC2cC05BE5b75445C896C89Fc58EbF5` |
| StateVerifier | `0xC8530c80D1e9Fb93119D0Db821267aD1676fd510` |
| UniswapV4Adapter | `0xc04cd85241e0DFD1C3aBb5500207D92eAda3dfD6` |
| MorphoAdapter | `0xA2266f24ed86C68E295621D099005BbB192284C5` |
| SpendingLimit | `0xe49968247D6bf3435e5819372ea1305149E69bfA` |
| ContractWhitelist | `0x70c4d1D1F792f2b4F9184e177842FCD171d6655e` |
| SlippageGuard | `0x7d02e2a7d22fc83192C6f2B8b56970B841E62476` |
| Drawdown | `0x2f69B6D365Ffcf056835718a6579380D237526B6` |

**Demo Contracts:**

| Contract | Address |
|---|---|
| DemoPriceFeed | `0x470BFcb45f597675d7Dae96286E24E92126D35Ba` |
| DemoSwapAdapter | `0x4DF7AC6C31066CA991517A250C16403aE1E81981` |
| DemoDepositAdapter | `0x22236366F4d5423BF1B33B7b7f4828125E9c96b6` |
| TestUSDC | `0x60bf7859556Ac6834ef6Cf7FcF7c4c64a47F831D` |

Explorer: `https://testnet.monadexplorer.com`

---

## Live Demo

The web interface at `/demo` provides a 1-click demonstration of the full CVE flow:

| Bot | Behavior | Expected Result |
|---|---|---|
| **HonestBot** | Correct price claim | PASS — swap executes, score +10 |
| **YieldBot** | Correct deposit claim | PASS — vault deposit, score +10 |
| **LiarBot** | 34% wrong price | HARD REJECT — refund + slash |
| **ManipBot** | Alters claim after commit | HASH FAIL — refund + slash |

Each scenario runs on real Monad testnet contracts with two separate wallets (user + agent). No MetaMask popups — the server executes both sides to show the full flow in ~5 seconds.

---

## Quick Start

### Prerequisites

- Node.js 20+, pnpm 9+
- Foundry (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- Monad testnet MON (Discord faucet)

### Install

```bash
pnpm install
```

### Build Contracts

```bash
cd contracts
forge build
forge test
```

### Build SDK

```bash
pnpm -r build
```

### Run Talos Terminal (Web UI)

```bash
cd web
cp .env.example .env.local    # Add funded testnet private keys
pnpm dev
# Open http://localhost:3000
```

### Run CLI Demo (5 scenarios)

```bash
cd bots
cp .env.example .env          # Add funded testnet private key
pnpm tsx src/demo.ts
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **No mocks** | Real Chainlink oracle, real ERC-20 tokens, real on-chain execution. Fork tests use live Monad mainnet state. |
| **Commit-Verify-Execute** | Agent commits claim hash first — can't change after. Prevents post-hoc rationalization. |
| **Standing escrow** | Funds locked per-intent, never accessible by agent. Eliminates trust requirement. |
| **Tiered tolerance** | Soft reject (1.5%) allows retry for network delays. Hard reject (5%+) slashes for malice. |
| **Dual penalty** | Score decrease + stake slash. Economic and reputational consequences. |
| **Modular architecture** | New verifiers and policies can be registered without upgrading core contract. |
| **Two-wallet model** | User wallet (locks escrow) and Agent wallet (commits/verifies) are strictly separated. |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity 0.8.28, Foundry, OpenZeppelin 5.x |
| Chain | Monad Testnet (10143) — Cancun EVM, 400ms blocks |
| Oracle | Chainlink AggregatorV3 (push feeds) |
| DEX | Uniswap V4 Universal Router |
| Yield | Morpho ERC-4626 Vaults |
| SDK | TypeScript, viem 2.x |
| Frontend | Next.js 15, wagmi 2.x, RainbowKit 2.x, TanStack Query |
| Testing | Forge (fork tests), Vitest |

---

## Security Considerations

- `ReentrancyGuard` on all state-changing functions
- Checks-Effects-Interactions pattern throughout
- `SafeERC20` for all token transfers
- Pull-over-push for refunds
- Intent expiry to prevent stale escrow lock-up
- Custom errors (gas-efficient reverts)
- No `unchecked` blocks without mathematical proof

---

## Roadmap

- [x] Core protocol (TalosProtocol.sol + escrow)
- [x] 3 verifier modules (Price, Balance, State)
- [x] 4 policy modules (SpendingLimit, Whitelist, Slippage, Drawdown)
- [x] Execution adapters (UniswapV4, Morpho)
- [x] TypeScript SDK with hash parity
- [x] Demo bots (4 scenarios)
- [x] Web terminal with live feed
- [x] Testnet deployment (Monad 10143)
- [ ] Multi-agent coordination (shared escrow pools)
- [ ] Cross-chain verification (LayerZero bridge)
- [ ] Agent marketplace with reputation staking
- [ ] Governance module for policy parameter updates

---

## License

MIT
