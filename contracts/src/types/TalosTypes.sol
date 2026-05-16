// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice All shared data types for the TALOS protocol.
///         Field names match TALOS-MONAD-proje-dokumani.md exactly.

// ═══════════════════════════════════════════════════════════
//  Escrow
// ═══════════════════════════════════════════════════════════

enum EscrowStatus {
    Locked,     // Fonlar kilitli, commit bekleniyor
    Committed,  // Ajan commit yapti, dogrulama bekleniyor
    Verified,   // Dogrulama gecti, yurutme bekleniyor
    Executed,   // Islem gerceklesti, fonlar dagitildi
    Refunded,   // Dogrulama basarisiz, fonlar iade edildi
    Expired     // Sure doldu, fonlar iade edildi
}

struct Escrow {
    bytes16 intentId;
    address owner;
    address agent;
    address token;
    uint256 amount;
    uint64 createdAt;
    uint64 expiry;
    EscrowStatus status;
    bytes32 commitHash;
    bool verified;
}

// ═══════════════════════════════════════════════════════════
//  Standing Escrow (v2 — DCA/Bot dostu surekli escrow)
// ═══════════════════════════════════════════════════════════

struct StandingEscrow {
    address owner;
    address agent;
    address token;
    uint256 balance;
    uint256 perTxLimit;
    uint64 expiry;
    bool active;
}

// ═══════════════════════════════════════════════════════════
//  Verification Record
// ═══════════════════════════════════════════════════════════

struct VerificationRecord {
    bytes16 intentId;
    address agent;
    uint8 decision;           // 0=Rejected, 1=Approved
    bool hashMatched;
    bool oracleMatched;
    bool policyPassed;
    uint8 failureCode;        // 0=yok, 1=hash, 2=fiyat, 3=politika
    uint256 claimedPrice;
    uint256 oraclePrice;
    uint16 priceDeviationBps;
    uint64 verifiedAt;
}

// ═══════════════════════════════════════════════════════════
//  Reputation (ELO-based, 0-2000)
// ═══════════════════════════════════════════════════════════

struct Reputation {
    address agent;
    uint16 score;              // 0-2000
    uint32 totalVerifications;
    uint32 passed;
    uint32 failed;
    uint256 totalVolume;       // USDC 6 dec / MON 18 dec
    uint256 stake;             // MON, 18 dec
    uint64 registeredAt;
    uint64 lastVerified;
    bool isBanned;
}

// ═══════════════════════════════════════════════════════════
//  Policy Config (v2 — meta-politika alanlari dahil)
// ═══════════════════════════════════════════════════════════

struct PolicyConfig {
    uint256 dailySpendingLimit;
    uint256 weeklySpendingLimit;
    address[] allowedContracts;
    uint16 maxSlippageBps;
    uint8 maxDrawdownPct;
    uint256 initialPortfolioValue;
    // Meta-politika: ajanin ayarlayabilecegi sinirlar
    uint256 maxDailyLimitCeiling;
    bool agentCanTighten;
    bool agentCanLoosen;
}

// ═══════════════════════════════════════════════════════════
//  Agent Claim — SDK hash parity icin ABI encoding sirasi NET
// ═══════════════════════════════════════════════════════════
//
//  SDK (TypeScript) ve kontrat (Solidity) AYNI hash'i uretmelidir:
//
//    hash = keccak256(abi.encode(
//        claim.priceFeed,        // address   — slot 0
//        claim.claimedPrice,     // uint256   — slot 1
//        claim.reasoning,        // string    — slot 2 (dynamic, offset pointer)
//        claim.action,           // string    — slot 3 (dynamic, offset pointer)
//        claim.protocol,         // address   — slot 4
//        claim.expectedOutputMin,// uint256   — slot 5
//        claim.timestamp,        // uint64    — slot 6 (left-padded to 32 bytes)
//        claim.expiry            // uint64    — slot 7 (left-padded to 32 bytes)
//    ))
//
//  SDK tarafinda viem'in encodeAbiParameters fonksiyonu ayni sirada kullanilir.
//  Hash parity testi zorunlu (Anayasa Kural #9).

struct AgentClaim {
    address priceFeed;
    uint256 claimedPrice;
    string reasoning;
    string action;
    address protocol;
    uint256 expectedOutputMin;
    uint64 timestamp;
    uint64 expiry;
}
