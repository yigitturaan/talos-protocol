// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Escrow, EscrowStatus, VerificationRecord, Reputation, PolicyConfig, StandingEscrow, AgentClaim} from "../types/TalosTypes.sol";
import {IVerifier} from "./IVerifier.sol";

/// @notice External interface for the TalosProtocol contract.
interface ITalosProtocol {
    // ═══════════════════════════════════════════════════════
    //  Events
    // ═══════════════════════════════════════════════════════

    event AgentRegistered(address indexed agent, uint256 stakeAmount);

    event EscrowLocked(
        bytes16 indexed intentId,
        address indexed owner,
        address indexed agent,
        address token,
        uint256 amount
    );

    event ClaimCommitted(bytes16 indexed intentId, address indexed agent, bytes32 claimHash);

    event VerificationPassed(bytes16 indexed intentId, address indexed agent);

    event VerificationFailed(bytes16 indexed intentId, address indexed agent, uint8 failureCode);

    event SoftRejection(bytes16 indexed intentId, uint16 deviationBps);

    event EscrowRefunded(bytes16 indexed intentId, address indexed owner, uint256 amount);

    event PolicyTightened(bytes16 indexed escrowId, uint256 newDailyLimit);

    event PolicyLoosened(bytes16 indexed escrowId, uint256 newDailyLimit);

    event PolicyUpdatedByOwner(bytes16 indexed escrowId, uint256 newDailyLimit);

    event StandingEscrowCreated(
        bytes32 indexed standingId,
        address indexed owner,
        address indexed agent,
        address token,
        uint256 amount,
        uint256 perTxLimit
    );

    event AgentSlashed(address indexed agent, uint256 slashAmount);

    event CircuitBreakerTripped(address indexed token, uint256 lastPrice, uint256 currentPrice);

    // ═══════════════════════════════════════════════════════
    //  Custom Errors
    // ═══════════════════════════════════════════════════════

    error InsufficientStake(uint256 provided, uint256 required);
    error AgentAlreadyRegistered(address agent);
    error AgentNotRegistered(address agent);
    error AgentBanned(address agent);
    error IntentAlreadyExists(bytes16 intentId);
    error InvalidExpiry(uint64 expiry);
    error InvalidEscrowStatus(bytes16 intentId, EscrowStatus current, EscrowStatus expected);
    error NotAuthorizedAgent(bytes16 intentId, address caller);
    error EscrowExpired(bytes16 intentId);
    error EscrowNotExpired(bytes16 intentId);
    error HashMismatch(bytes32 expected, bytes32 actual);
    error StaleOracleData(uint256 updatedAt, uint256 maxAge);
    error CircuitBreakerActive(address token);
    error ExceedsPerTxLimit(uint256 amount, uint256 limit);
    error InsufficientStandingBalance(uint256 available, uint256 requested);
    error StandingEscrowExpired(bytes32 standingId);
    error StandingEscrowInactive(bytes32 standingId);
    error NoLoosenPermission();
    error ExceedsCeiling(uint256 requested, uint256 ceiling);
    error NotOwnerOrAgent(address caller);

    // ═══════════════════════════════════════════════════════
    //  Agent Management
    // ═══════════════════════════════════════════════════════

    function registerAgent(uint256 stakeAmount) external payable;

    // ═══════════════════════════════════════════════════════
    //  Escrow (single intent)
    // ═══════════════════════════════════════════════════════

    function lockEscrow(
        bytes16 intentId,
        address agent,
        address token,
        uint256 amount,
        uint64 expiry
    ) external;

    function lockEscrowWithPermit(
        bytes16 intentId,
        address agent,
        address token,
        uint256 amount,
        uint64 expiry,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // ═══════════════════════════════════════════════════════
    //  Commit-Verify-Execute
    // ═══════════════════════════════════════════════════════

    function commit(bytes16 intentId, bytes32 claimHash) external;

    function verifyAndExecute(
        bytes16 intentId,
        bytes calldata claimData,
        address[] calldata references
    ) external;

    // ═══════════════════════════════════════════════════════
    //  Refund
    // ═══════════════════════════════════════════════════════

    function refund(bytes16 intentId) external;

    // ═══════════════════════════════════════════════════════
    //  Standing Escrow (v2)
    // ═══════════════════════════════════════════════════════

    function createStandingEscrow(
        address agent,
        address token,
        uint256 amount,
        uint256 perTxLimit,
        uint64 expiry
    ) external;

    function executeFromStanding(
        bytes32 standingId,
        bytes16 intentId,
        uint256 amount,
        bytes calldata claimData,
        address[] calldata references
    ) external;

    function withdrawStandingEscrow(bytes32 standingId) external;

    // ═══════════════════════════════════════════════════════
    //  Policy Management (v2 — meta-policy)
    // ═══════════════════════════════════════════════════════

    function adjustPolicy(bytes16 escrowId, uint256 newDailyLimit) external;

    // ═══════════════════════════════════════════════════════
    //  View Functions
    // ═══════════════════════════════════════════════════════

    function escrows(bytes16 intentId) external view returns (Escrow memory);

    function verifications(bytes16 intentId) external view returns (VerificationRecord memory);

    function reputations(address agent) external view returns (Reputation memory);

    function standingEscrows(bytes32 standingId) external view returns (StandingEscrow memory);
}
