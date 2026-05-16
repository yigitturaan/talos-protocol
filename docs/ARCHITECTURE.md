# TALOS — Technical Architecture

## System Overview

Talos is a pre-trade verification protocol for autonomous AI agents. It implements a **Commit-Verify-Execute (CVE)** pattern where agents must cryptographically commit to their data claims before execution, and those claims are verified against real oracle and on-chain data.

```
┌──────────────────────────────────────────────────────────────────────┐
│                         AGENT (off-chain)                             │
│  AI bot generates trade signal → builds AgentClaim → commits hash    │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    TalosProtocol.sol     │
                    │                         │
                    │  1. commit(intentId,     │
                    │     claimHash)           │
                    │                         │
                    │  2. verifyAndExecute(    │
                    │     intentId, claim,     │
                    │     feeds[])             │
                    │     ├─ Hash check       │
                    │     ├─ Verifiers[]      │
                    │     ├─ Policies[]       │
                    │     └─ Execute          │
                    │                         │
                    │  3. Escrow release/      │
                    │     refund + rep update  │
                    └─────────────────────────┘
                          │           │
              ┌───────────┘           └───────────┐
              ▼                                   ▼
┌──────────────────────┐            ┌──────────────────────┐
│    Verifiers         │            │   Policy Engines     │
│  ┌────────────────┐  │            │  ┌────────────────┐  │
│  │ PriceVerifier  │  │            │  │ SpendingLimit  │  │
│  │ (Chainlink)    │  │            │  │ (daily/weekly) │  │
│  ├────────────────┤  │            │  ├────────────────┤  │
│  │BalanceVerifier │  │            │  │ContractWhitelist│ │
│  │ (ERC-20 check) │  │            │  ├────────────────┤  │
│  ├────────────────┤  │            │  │ SlippageGuard  │  │
│  │ StateVerifier  │  │            │  │ (max slippage) │  │
│  │ (arbitrary)    │  │            │  ├────────────────┤  │
│  └────────────────┘  │            │  │   Drawdown     │  │
└──────────────────────┘            │  │ (max loss %)   │  │
                                    │  └────────────────┘  │
                                    └──────────────────────┘
              │
              ▼
┌──────────────────────┐
│  Execution Adapters  │
│  ┌────────────────┐  │
│  │UniswapV4Adapter│  │    Uniswap V4 Universal Router
│  ├────────────────┤  │
│  │ MorphoAdapter  │  │    Morpho ERC-4626 Vaults
│  └────────────────┘  │
└──────────────────────┘
```

---

## Core Flow: Commit-Verify-Execute (CVE)

### Step 1: Commit

```
Agent → commit(intentId, keccak256(abi.encode(AgentClaim)))
```

- Agent generates a unique `intentId` (random bytes32)
- Agent builds an `AgentClaim` struct with price assertion, action, reasoning
- Agent hashes the claim using deterministic ABI encoding
- Hash is stored on-chain — agent can no longer change the claim

### Step 2: Verify & Execute

```
Agent → verifyAndExecute(intentId, claim, priceFeedAddresses)
```

The protocol runs a 3-layer verification pipeline:

1. **Hash Integrity** — `keccak256(abi.encode(claim)) == storedHash`? If not → immediate reject + slash
2. **Verifier Pipeline** — Each registered verifier checks the claim:
   - `PriceVerifier`: Compares `claim.claimedPrice` vs Chainlink `latestRoundData()`
   - `BalanceVerifier`: Confirms claimed token balances match actual `balanceOf()`
   - `StateVerifier`: Validates arbitrary on-chain state assertions
3. **Policy Pipeline** — Each registered policy checks constraints:
   - `SpendingLimit`: Daily/weekly spending cap
   - `ContractWhitelist`: Target contract must be in allowlist
   - `SlippageGuard`: `expectedOutputMin` within acceptable range
   - `Drawdown`: Portfolio loss hasn't exceeded threshold

### Step 3: Outcome

| Result | Action |
|---|---|
| All pass | Execute trade (via adapter), release escrow, reputation +10 |
| Soft reject (1.5%-5% deviation) | No execute, escrow held, reputation -5, agent can retry |
| Hard reject (>5% deviation) | No execute, escrow refunded minus slash, reputation -50, stake slashed 10% |
| Hash mismatch | No execute, escrow refunded minus slash, reputation -100, stake slashed 10% |

---

## Contract Architecture

### TalosProtocol.sol (Core)

The central contract managing the full lifecycle:

- **Agent Registry**: `registerAgent(stake)` — minimum 100 MON stake
- **Escrow Management**: `lockEscrow(intentId, token, amount, expiry)` — per-intent fund locking
- **Commit**: `commit(intentId, claimHash)` — stores hash commitment
- **Verify & Execute**: `verifyAndExecute(intentId, claim, feeds)` — runs full pipeline
- **Reputation**: On-chain ELO-style score (start 1000, ban at 100)

### Verifier Interface (IVerifier.sol)

```solidity
interface IVerifier {
    function verify(
        bytes32 intentId,
        AgentClaim calldata claim,
        address[] calldata feeds
    ) external view returns (VerificationResult);
}
```

Returns: `PASS`, `SOFT_REJECT`, `HARD_REJECT`

### Policy Interface (IPolicyEngine.sol)

```solidity
interface IPolicyEngine {
    function check(
        address agent,
        bytes32 intentId,
        AgentClaim calldata claim
    ) external view returns (bool allowed, string memory reason);
}
```

### Tiered Tolerance (PriceVerifier)

```
deviation = |claimedPrice - oraclePrice| / oraclePrice

0% ─────── 1.5% ─────── 5% ─────── 10%+ ──────
   PASS        SOFT         HARD        CIRCUIT
              REJECT       REJECT       BREAKER
```

- **Soft tolerance (150 bps)**: Network delay margin — allows retry
- **Hard tolerance (500 bps)**: Malicious threshold — slash + reject
- **Circuit breaker (1000 bps)**: Emergency halt — all operations paused

---

## Data Model: AgentClaim

```solidity
struct AgentClaim {
    address priceFeed;          // Chainlink feed address for verification
    uint256 claimedPrice;       // Agent's price assertion (8 or 18 decimals)
    string  reasoning;          // Human-readable reasoning (stored in hash)
    string  action;             // "BUY_MON", "SELL_ETH", "DEPOSIT", etc.
    address protocol;           // Target protocol/token address
    uint256 expectedOutputMin;  // Minimum acceptable output
    uint256 timestamp;          // Claim creation time
    uint256 expiry;             // Claim validity window
}
```

**Hash Parity**: SDK and contract use identical `keccak256(abi.encode(AgentClaim))` encoding. Hash parity is enforced by integration tests.

---

## Escrow Model

```
┌─────────────────────────────────────────────┐
│            Standing Escrow                    │
│                                             │
│  User deposits funds per intent:            │
│  lockEscrow(intentId, token, amount, expiry)│
│                                             │
│  On PASS:                                   │
│    → Funds released to execution adapter    │
│    → Adapter executes swap/deposit          │
│    → Output returned to user               │
│                                             │
│  On REJECT:                                 │
│    → Funds returned to user (minus slash)   │
│    → Agent stake slashed (hard reject)      │
│                                             │
│  On EXPIRY:                                 │
│    → User can reclaim unverified escrow     │
└─────────────────────────────────────────────┘
```

---

## Reputation System (ELO-style)

| Event | Score Change |
|---|---|
| Verification PASS | +10 |
| Soft reject | -5 |
| Hard reject | -50 |
| Hash mismatch | -100 |
| Ban threshold | Score drops to 100 → agent banned |
| Initial score | 1000 |

Reputation is fully on-chain and queryable. The Talos Terminal displays a live leaderboard.

---

## Execution Adapters

### UniswapV4Adapter

- Encodes swap commands for Uniswap V4 Universal Router
- Supports exact-input single-hop and multi-hop swaps
- Uses Permit2 for token approvals
- Mainnet addresses used in fork tests; demo adapter on testnet

### MorphoAdapter

- Deposits into Morpho ERC-4626 vaults
- Supports USDC and WETH vaults on Monad
- Standard `deposit(assets, receiver)` interface

---

## Monad-Native Design

| Monad Feature | Talos Benefit |
|---|---|
| 400ms block time | CVE completes in ~2 seconds (5 blocks) |
| 10,000 TPS | Handles high-frequency agent verification |
| Deferred Execution (N-2 lag) | Escrow model neutralizes state uncertainty |
| Cancun EVM (full opcode compat) | Standard Solidity, no modifications needed |
| Low gas (~$0.001/tx) | Verification overhead is negligible |

---

## SDK (@talos-protocol/sdk)

TypeScript SDK providing:

- `TalosSDK` class: High-level methods (`commit`, `verifyAndExecute`, `lockEscrow`, etc.)
- `hashClaim(claim)`: Deterministic claim hashing (matches on-chain encoding)
- `encodeClaim(claim)`: ABI encode for contract interaction
- `generateIntentId()`: Random bytes32 intent identifier
- `monadTestnet` / `monad` chain definitions for viem
- Full contract ABIs exported

---

## Testing Strategy

| Layer | Tool | What's Tested |
|---|---|---|
| Unit (contracts) | `forge test` | Individual functions, libraries, edge cases |
| Fork (contracts) | `forge test --fork-url rpc.monad.xyz` | Real oracle prices, real DEX state |
| Unit (SDK) | `vitest` | Hash parity, encoding, type safety |
| Integration (SDK) | `vitest` (integration config) | SDK ↔ testnet contract interaction |
| E2E (demo) | `bots/src/demo.ts` | Full 5-scenario jury flow on testnet |

---

## Security Measures

- `ReentrancyGuard` on all state-mutating functions
- Checks-effects-interactions pattern throughout
- `SafeERC20` for all token transfers
- Custom errors (gas efficient, descriptive)
- Pull-over-push for refunds
- No `unchecked` blocks without mathematical proof
- Circuit breaker for extreme market conditions (>10% oracle deviation)
