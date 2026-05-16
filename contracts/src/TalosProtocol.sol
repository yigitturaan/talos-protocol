// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {
    Escrow,
    EscrowStatus,
    VerificationRecord,
    Reputation,
    PolicyConfig,
    StandingEscrow,
    AgentClaim
} from "./types/TalosTypes.sol";
import {ITalosProtocol} from "./interfaces/ITalosProtocol.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {IPolicyEngine} from "./interfaces/IPolicyEngine.sol";
import {ClaimEncoder} from "./libraries/ClaimEncoder.sol";
import {ReputationLib} from "./libraries/ReputationLib.sol";
import {UniswapV4Adapter, SwapParams} from "./execution/UniswapV4Adapter.sol";
import {MorphoAdapter} from "./execution/MorphoAdapter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TalosProtocol is ITalosProtocol, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using ClaimEncoder for AgentClaim;

    // ═══════════════════════════════════════════════════════
    //  Constants (Section 11)
    // ═══════════════════════════════════════════════════════

    uint256 public constant MIN_STAKE = 100 ether;
    uint16 public constant VERIFICATION_FEE_BPS = 5;       // 0.05%
    uint16 public constant SLASH_PERCENT = 10;              // 10% of stake
    uint16 public constant PRICE_TOLERANCE_BPS = 100;       // 1% (legacy)
    uint16 public constant INITIAL_SCORE = 1000;
    uint16 public constant BAN_THRESHOLD = 100;
    uint16 public constant CIRCUIT_BREAKER_BPS = 1000;      // 10% drop threshold

    // ═══════════════════════════════════════════════════════
    //  Storage
    // ═══════════════════════════════════════════════════════

    mapping(bytes16 => Escrow) private _escrows;
    mapping(bytes16 => VerificationRecord) private _verifications;
    mapping(address => Reputation) private _reputations;
    mapping(bytes32 => StandingEscrow) private _standingEscrows;
    mapping(bytes16 => PolicyConfig) private _policies;

    // Policy engine registry
    address[] private _policyEngines;
    mapping(address => bool) private _isPolicyEngine;

    // Verifier
    IVerifier public priceVerifier;

    // Execution adapters
    UniswapV4Adapter public swapAdapter;
    MorphoAdapter public depositAdapter;

    // Circuit breaker: last verified price per feed address
    mapping(address => uint256) private _lastVerifiedPrice;

    // ═══════════════════════════════════════════════════════
    //  Constructor
    // ═══════════════════════════════════════════════════════

    constructor(address initialOwner) Ownable(initialOwner) {}

    // ═══════════════════════════════════════════════════════
    //  Policy Engine Registry
    // ═══════════════════════════════════════════════════════

    event PolicyEngineUpdated(address indexed engine, bool enabled);

    function setPolicyEngine(address engine, bool enabled) external onlyOwner {
        if (enabled && !_isPolicyEngine[engine]) {
            _isPolicyEngine[engine] = true;
            _policyEngines.push(engine);
            emit PolicyEngineUpdated(engine, true);
        } else if (!enabled && _isPolicyEngine[engine]) {
            _isPolicyEngine[engine] = false;
            uint256 len = _policyEngines.length;
            for (uint256 i; i < len;) {
                if (_policyEngines[i] == engine) {
                    _policyEngines[i] = _policyEngines[len - 1];
                    _policyEngines.pop();
                    break;
                }
                unchecked { ++i; }
            }
            emit PolicyEngineUpdated(engine, false);
        }
    }

    function policyEngines() external view returns (address[] memory) {
        return _policyEngines;
    }

    // ═══════════════════════════════════════════════════════
    //  Adapter & Verifier Management
    // ═══════════════════════════════════════════════════════

    event SwapAdapterUpdated(address indexed adapter);
    event DepositAdapterUpdated(address indexed adapter);
    event PriceVerifierUpdated(address indexed verifier);

    function setSwapAdapter(address adapter) external onlyOwner {
        swapAdapter = UniswapV4Adapter(payable(adapter));
        emit SwapAdapterUpdated(adapter);
    }

    function setDepositAdapter(address adapter) external onlyOwner {
        depositAdapter = MorphoAdapter(adapter);
        emit DepositAdapterUpdated(adapter);
    }

    function setPriceVerifier(address verifier) external onlyOwner {
        priceVerifier = IVerifier(verifier);
        emit PriceVerifierUpdated(verifier);
    }

    // ═══════════════════════════════════════════════════════
    //  View accessors (ITalosProtocol)
    // ═══════════════════════════════════════════════════════

    function escrows(bytes16 intentId) external view returns (Escrow memory) {
        return _escrows[intentId];
    }

    function verifications(bytes16 intentId) external view returns (VerificationRecord memory) {
        return _verifications[intentId];
    }

    function reputations(address agent) external view returns (Reputation memory) {
        return _reputations[agent];
    }

    function standingEscrows(bytes32 standingId) external view returns (StandingEscrow memory) {
        return _standingEscrows[standingId];
    }

    // ═══════════════════════════════════════════════════════
    //  1. registerAgent
    // ═══════════════════════════════════════════════════════

    function registerAgent(uint256 stakeAmount) external payable {
        if (stakeAmount < MIN_STAKE) {
            revert InsufficientStake(stakeAmount, MIN_STAKE);
        }
        if (_reputations[msg.sender].registeredAt != 0) {
            revert AgentAlreadyRegistered(msg.sender);
        }
        if (msg.value < stakeAmount) {
            revert InsufficientStake(msg.value, stakeAmount);
        }

        _reputations[msg.sender] = Reputation({
            agent: msg.sender,
            score: INITIAL_SCORE,
            totalVerifications: 0,
            passed: 0,
            failed: 0,
            totalVolume: 0,
            stake: stakeAmount,
            registeredAt: uint64(block.timestamp),
            lastVerified: 0,
            isBanned: false
        });

        emit AgentRegistered(msg.sender, stakeAmount);
    }

    // ═══════════════════════════════════════════════════════
    //  2. lockEscrow
    // ═══════════════════════════════════════════════════════

    function lockEscrow(
        bytes16 intentId,
        address agent,
        address token,
        uint256 amount,
        uint64 expiry
    ) external nonReentrant {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _createEscrow(intentId, msg.sender, agent, token, amount, expiry);
    }

    // ═══════════════════════════════════════════════════════
    //  2b. lockEscrowWithPermit (v2 — single tx)
    // ═══════════════════════════════════════════════════════

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
    ) external nonReentrant {
        IERC20Permit(token).permit(msg.sender, address(this), amount, deadline, v, r, s);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _createEscrow(intentId, msg.sender, agent, token, amount, expiry);
    }

    // ═══════════════════════════════════════════════════════
    //  3. commit
    // ═══════════════════════════════════════════════════════

    function commit(bytes16 intentId, bytes32 claimHash) external {
        Escrow storage esc = _escrows[intentId];

        if (esc.agent != msg.sender) {
            revert NotAuthorizedAgent(intentId, msg.sender);
        }
        if (esc.status != EscrowStatus.Locked) {
            revert InvalidEscrowStatus(intentId, esc.status, EscrowStatus.Locked);
        }
        if (block.timestamp >= esc.expiry) {
            revert EscrowExpired(intentId);
        }

        esc.commitHash = claimHash;
        esc.status = EscrowStatus.Committed;

        emit ClaimCommitted(intentId, msg.sender, claimHash);
    }

    // ═══════════════════════════════════════════════════════
    //  4. verifyAndExecute — 3-layer verification (Section 7+8+11)
    // ═══════════════════════════════════════════════════════

    function verifyAndExecute(
        bytes16 intentId,
        bytes calldata claimData,
        address[] calldata references
    ) external nonReentrant {
        Escrow storage esc = _escrows[intentId];

        // Guards
        if (esc.agent != msg.sender) {
            revert NotAuthorizedAgent(intentId, msg.sender);
        }
        if (esc.status != EscrowStatus.Committed) {
            revert InvalidEscrowStatus(intentId, esc.status, EscrowStatus.Committed);
        }
        if (block.timestamp >= esc.expiry) {
            revert EscrowExpired(intentId);
        }

        _verifyAndExecuteInternal(intentId, claimData, references);
    }

    function _verifyAndExecuteInternal(
        bytes16 intentId,
        bytes calldata claimData,
        address[] calldata references
    ) internal {
        Escrow storage esc = _escrows[intentId];
        AgentClaim memory claim = ClaimEncoder.decode(claimData);

        // Circuit breaker — check FIRST before any verification
        _checkCircuitBreaker(claim.priceFeed);

        // ── LAYER 1: Hash commitment ──
        bytes32 computedHash = keccak256(claimData);
        bool hashMatched = (computedHash == esc.commitHash);

        if (!hashMatched) {
            _failVerification(esc, intentId, FailParams({
                claimedPrice: 0,
                oraclePrice: 0,
                hashMatched: false,
                oracleMatched: false,
                policyPassed: false,
                failureCode: 1,
                outcome: ReputationLib.Outcome.HashFailed
            }));
            return;
        }

        // ── LAYER 2: Oracle verification (PriceVerifier) ──
        IVerifier.VerificationOutput memory vOut = priceVerifier.verify(claimData, references);

        if (vOut.result == IVerifier.VerificationResult.SoftReject) {
            // Revert escrow to Locked — agent can retry (no slash)
            esc.status = EscrowStatus.Locked;
            esc.commitHash = bytes32(0);
            _updateReputation(esc.agent, ReputationLib.Outcome.SoftReject);
            emit SoftRejection(intentId, vOut.deviationBps);
            return;
        }

        if (vOut.result == IVerifier.VerificationResult.HardReject) {
            _failVerification(esc, intentId, FailParams({
                claimedPrice: claim.claimedPrice,
                oraclePrice: _readOraclePrice(claim.priceFeed),
                hashMatched: true,
                oracleMatched: false,
                policyPassed: false,
                failureCode: 2,
                outcome: ReputationLib.Outcome.OracleFailed
            }));
            return;
        }

        // ── LAYER 3: Policy check ──
        bool policyPassed = true;
        try this._externalCheckPolicies(claimData, esc.agent, esc.amount, claim.protocol) {
            // policies passed
        } catch {
            policyPassed = false;
        }

        if (!policyPassed) {
            _failVerification(esc, intentId, FailParams({
                claimedPrice: claim.claimedPrice,
                oraclePrice: _readOraclePrice(claim.priceFeed),
                hashMatched: true,
                oracleMatched: true,
                policyPassed: false,
                failureCode: 3,
                outcome: ReputationLib.Outcome.PolicyFailed
            }));
            return;
        }

        // ── ALL LAYERS PASSED → Execute ──
        _successVerification(esc, intentId, claim);
    }

    // External wrapper so _checkAllPolicies revert can be caught by try/catch
    function _externalCheckPolicies(
        bytes calldata claimData,
        address agent,
        uint256 amount,
        address targetContract
    ) external view {
        if (msg.sender != address(this)) revert NotAuthorizedAgent(bytes16(0), msg.sender);
        _checkAllPolicies(claimData, agent, amount, targetContract);
    }

    // ═══════════════════════════════════════════════════════
    //  5. refund — permissionless, expired escrows (Section 11)
    // ═══════════════════════════════════════════════════════

    function refund(bytes16 intentId) external nonReentrant {
        Escrow storage esc = _escrows[intentId];

        if (esc.createdAt == 0) {
            revert IntentAlreadyExists(intentId); // escrow doesn't exist
        }
        if (esc.status != EscrowStatus.Locked && esc.status != EscrowStatus.Committed) {
            revert InvalidEscrowStatus(intentId, esc.status, EscrowStatus.Locked);
        }
        if (block.timestamp < esc.expiry) {
            revert EscrowNotExpired(intentId);
        }

        esc.status = EscrowStatus.Expired;

        // Return funds to owner
        IERC20(esc.token).safeTransfer(esc.owner, esc.amount);

        // Timeout reputation penalty
        _updateReputation(esc.agent, ReputationLib.Outcome.Timeout);

        emit EscrowRefunded(intentId, esc.owner, esc.amount);
    }

    // ═══════════════════════════════════════════════════════
    //  Standing Escrow (v2 — DCA/bot friendly)
    // ═══════════════════════════════════════════════════════

    event StandingEscrowWithdrawn(bytes32 indexed standingId, address indexed owner, uint256 amount);

    function createStandingEscrow(
        address agent,
        address token,
        uint256 amount,
        uint256 perTxLimit,
        uint64 expiry
    ) external nonReentrant {
        if (_reputations[agent].registeredAt == 0) revert AgentNotRegistered(agent);
        if (_reputations[agent].isBanned) revert AgentBanned(agent);
        if (expiry <= block.timestamp) revert InvalidExpiry(expiry);
        if (perTxLimit == 0 || perTxLimit > amount) revert ExceedsPerTxLimit(perTxLimit, amount);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        bytes32 standingId = keccak256(abi.encode(msg.sender, agent, token, block.timestamp));

        _standingEscrows[standingId] = StandingEscrow({
            owner: msg.sender,
            agent: agent,
            token: token,
            balance: amount,
            perTxLimit: perTxLimit,
            expiry: expiry,
            active: true
        });

        emit StandingEscrowCreated(standingId, msg.sender, agent, token, amount, perTxLimit);
    }

    function executeFromStanding(
        bytes32 standingId,
        bytes16 intentId,
        uint256 amount,
        bytes calldata claimData,
        address[] calldata references
    ) external nonReentrant {
        StandingEscrow storage se = _standingEscrows[standingId];

        if (!se.active) revert StandingEscrowInactive(standingId);
        if (block.timestamp >= se.expiry) revert StandingEscrowExpired(standingId);
        if (msg.sender != se.agent) revert NotAuthorizedAgent(intentId, msg.sender);
        if (amount > se.perTxLimit) revert ExceedsPerTxLimit(amount, se.perTxLimit);
        if (amount > se.balance) revert InsufficientStandingBalance(se.balance, amount);

        se.balance -= amount;

        if (_escrows[intentId].createdAt != 0) revert IntentAlreadyExists(intentId);

        _escrows[intentId] = Escrow({
            intentId: intentId,
            owner: se.owner,
            agent: se.agent,
            token: se.token,
            amount: amount,
            createdAt: uint64(block.timestamp),
            expiry: se.expiry,
            status: EscrowStatus.Committed,
            commitHash: keccak256(claimData),
            verified: false
        });

        emit EscrowLocked(intentId, se.owner, se.agent, se.token, amount);
        emit ClaimCommitted(intentId, se.agent, keccak256(claimData));

        _verifyAndExecuteInternal(intentId, claimData, references);
    }

    function withdrawStandingEscrow(bytes32 standingId) external nonReentrant {
        StandingEscrow storage se = _standingEscrows[standingId];
        if (msg.sender != se.owner) revert NotOwnerOrAgent(msg.sender);
        if (se.balance == 0) revert InsufficientStandingBalance(0, 1);

        uint256 amount = se.balance;
        se.balance = 0;
        se.active = false;

        IERC20(se.token).safeTransfer(se.owner, amount);

        emit StandingEscrowWithdrawn(standingId, se.owner, amount);
    }

    // ═══════════════════════════════════════════════════════
    //  Policy Management — meta-policy (Section 8)
    // ═══════════════════════════════════════════════════════

    function adjustPolicy(bytes16 escrowId, uint256 newDailyLimit) external {
        Escrow storage esc = _escrows[escrowId];
        PolicyConfig storage pol = _policies[escrowId];

        bool isOwner = (msg.sender == esc.owner);
        bool isAgent = (msg.sender == esc.agent);

        if (!isOwner && !isAgent) {
            revert NotOwnerOrAgent(msg.sender);
        }

        uint256 currentLimit = pol.dailySpendingLimit;

        if (isOwner) {
            // Owner can set any value
            pol.dailySpendingLimit = newDailyLimit;
            emit PolicyUpdatedByOwner(escrowId, newDailyLimit);
            return;
        }

        // Agent adjustments
        if (newDailyLimit < currentLimit) {
            // Tightening — always allowed
            pol.dailySpendingLimit = newDailyLimit;
            emit PolicyTightened(escrowId, newDailyLimit);
        } else {
            // Loosening — only if permitted and within ceiling
            if (!pol.agentCanLoosen) {
                revert NoLoosenPermission();
            }
            if (newDailyLimit > pol.maxDailyLimitCeiling) {
                revert ExceedsCeiling(newDailyLimit, pol.maxDailyLimitCeiling);
            }
            pol.dailySpendingLimit = newDailyLimit;
            emit PolicyLoosened(escrowId, newDailyLimit);
        }
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _createEscrow
    // ═══════════════════════════════════════════════════════

    function _createEscrow(
        bytes16 intentId,
        address owner_,
        address agent,
        address token,
        uint256 amount,
        uint64 expiry
    ) internal {
        if (_escrows[intentId].createdAt != 0) {
            revert IntentAlreadyExists(intentId);
        }
        if (_reputations[agent].registeredAt == 0) {
            revert AgentNotRegistered(agent);
        }
        if (_reputations[agent].isBanned) {
            revert AgentBanned(agent);
        }
        if (expiry <= block.timestamp) {
            revert InvalidExpiry(expiry);
        }

        _escrows[intentId] = Escrow({
            intentId: intentId,
            owner: owner_,
            agent: agent,
            token: token,
            amount: amount,
            createdAt: uint64(block.timestamp),
            expiry: expiry,
            status: EscrowStatus.Locked,
            commitHash: bytes32(0),
            verified: false
        });

        emit EscrowLocked(intentId, owner_, agent, token, amount);
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _executeAction
    // ═══════════════════════════════════════════════════════

    error UnsupportedAction(string action);
    error NoSwapAdapter();
    error NoDepositAdapter();

    function _executeAction(
        Escrow storage esc,
        AgentClaim memory claim
    ) internal returns (uint256 outputAmount) {
        bytes32 actionHash = keccak256(bytes(claim.action));

        if (actionHash == keccak256("BUY_MON") || actionHash == keccak256("SWAP")) {
            if (address(swapAdapter) == address(0)) revert NoSwapAdapter();

            IERC20(esc.token).safeIncreaseAllowance(address(swapAdapter), esc.amount);

            outputAmount = swapAdapter.swap(SwapParams({
                inputToken: esc.token,
                outputToken: claim.protocol,
                fee: 3000,
                tickSpacing: 60,
                hooks: address(0),
                amountIn: esc.amount,
                minAmountOut: claim.expectedOutputMin,
                recipient: esc.owner
            }));
        } else if (actionHash == keccak256("DEPOSIT")) {
            if (address(depositAdapter) == address(0)) revert NoDepositAdapter();

            IERC20(esc.token).safeTransfer(address(depositAdapter), esc.amount);

            outputAmount = depositAdapter.deposit(
                claim.protocol,  // vault address
                esc.token,
                esc.amount,
                claim.expectedOutputMin,  // min shares
                esc.owner
            );
        } else {
            revert UnsupportedAction(claim.action);
        }
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _checkAllPolicies
    // ═══════════════════════════════════════════════════════

    error PolicyDenied(string policy, string reason);

    function _checkAllPolicies(
        bytes calldata claimData,
        address agent,
        uint256 amount,
        address targetContract
    ) internal view {
        uint256 len = _policyEngines.length;
        for (uint256 i; i < len;) {
            IPolicyEngine.PolicyOutput memory out =
                IPolicyEngine(_policyEngines[i]).check(claimData, agent, amount, targetContract);
            if (out.result == IPolicyEngine.PolicyResult.Denied) {
                revert PolicyDenied(out.policy, out.reason);
            }
            unchecked { ++i; }
        }
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _checkCircuitBreaker (Section 8 — 10% drop)
    // ═══════════════════════════════════════════════════════

    function _checkCircuitBreaker(address priceFeed) internal view {
        if (priceFeed == address(0)) return;

        uint256 lastPrice = _lastVerifiedPrice[priceFeed];
        if (lastPrice == 0) return; // no baseline yet — skip

        uint256 currentPrice = _readOraclePrice(priceFeed);
        if (currentPrice >= lastPrice) return; // no drop

        uint256 dropBps = ((lastPrice - currentPrice) * 10000) / lastPrice;
        if (dropBps >= CIRCUIT_BREAKER_BPS) {
            revert CircuitBreakerActive(priceFeed);
        }
    }

    function _readOraclePrice(address priceFeed) internal view returns (uint256) {
        if (priceFeed == address(0)) return 0;
        (, int256 answer,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        if (answer <= 0) return 0;
        return uint256(answer);
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _slashAgent (10% of stake to protocol treasury)
    // ═══════════════════════════════════════════════════════

    function _slashAgent(address agent) internal {
        Reputation storage rep = _reputations[agent];
        if (rep.stake == 0) return;

        uint256 slashAmount = (rep.stake * SLASH_PERCENT) / 100;
        rep.stake -= slashAmount;

        if (rep.score < BAN_THRESHOLD) {
            rep.isBanned = true;
        }

        emit AgentSlashed(agent, slashAmount);
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _updateReputation (ReputationLib ELO)
    // ═══════════════════════════════════════════════════════

    function _updateReputation(address agent, ReputationLib.Outcome outcome) internal {
        Reputation storage rep = _reputations[agent];
        (uint16 newScore, bool banned) = ReputationLib.applyResult(rep, outcome);
        rep.score = newScore;
        if (banned) {
            rep.isBanned = true;
        }
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _successVerification (shared success path)
    // ═══════════════════════════════════════════════════════

    function _successVerification(
        Escrow storage esc,
        bytes16 intentId,
        AgentClaim memory claim
    ) internal {
        esc.status = EscrowStatus.Executed;
        esc.verified = true;

        uint256 fee = (esc.amount * VERIFICATION_FEE_BPS) / 10000;
        uint256 execAmount = esc.amount - fee;
        uint256 originalAmount = esc.amount;

        esc.amount = execAmount;
        _executeAction(esc, claim);
        esc.amount = originalAmount;

        _lastVerifiedPrice[claim.priceFeed] = _readOraclePrice(claim.priceFeed);
        _updateReputation(esc.agent, ReputationLib.Outcome.Passed);

        Reputation storage rep = _reputations[esc.agent];
        rep.totalVerifications += 1;
        rep.passed += 1;
        rep.totalVolume += originalAmount;
        rep.lastVerified = uint64(block.timestamp);

        _writeSuccessRecord(intentId, esc.agent, claim.claimedPrice, claim.priceFeed);
        emit VerificationPassed(intentId, esc.agent);
    }

    function _writeSuccessRecord(
        bytes16 intentId,
        address agent,
        uint256 claimedPrice,
        address priceFeed
    ) internal {
        _verifications[intentId] = VerificationRecord({
            intentId: intentId,
            agent: agent,
            decision: 1,
            hashMatched: true,
            oracleMatched: true,
            policyPassed: true,
            failureCode: 0,
            claimedPrice: claimedPrice,
            oraclePrice: _readOraclePrice(priceFeed),
            priceDeviationBps: 0,
            verifiedAt: uint64(block.timestamp)
        });
    }

    // ═══════════════════════════════════════════════════════
    //  Internal: _failVerification (shared fail path)
    // ═══════════════════════════════════════════════════════

    struct FailParams {
        uint256 claimedPrice;
        uint256 oraclePrice;
        bool hashMatched;
        bool oracleMatched;
        bool policyPassed;
        uint8 failureCode;
        ReputationLib.Outcome outcome;
    }

    function _failVerification(
        Escrow storage esc,
        bytes16 intentId,
        FailParams memory p
    ) internal {
        esc.status = EscrowStatus.Refunded;

        IERC20(esc.token).safeTransfer(esc.owner, esc.amount);
        _slashAgent(esc.agent);
        _updateReputation(esc.agent, p.outcome);

        Reputation storage rep = _reputations[esc.agent];
        rep.totalVerifications += 1;
        rep.failed += 1;
        rep.lastVerified = uint64(block.timestamp);

        uint16 devBps;
        if (p.oraclePrice > 0 && p.claimedPrice > 0) {
            uint256 diff = p.claimedPrice > p.oraclePrice
                ? p.claimedPrice - p.oraclePrice
                : p.oraclePrice - p.claimedPrice;
            uint256 raw = (diff * 10000) / p.oraclePrice;
            devBps = raw > 10000 ? 10000 : uint16(raw);
        }

        _verifications[intentId] = VerificationRecord({
            intentId: intentId,
            agent: esc.agent,
            decision: 0,
            hashMatched: p.hashMatched,
            oracleMatched: p.oracleMatched,
            policyPassed: p.policyPassed,
            failureCode: p.failureCode,
            claimedPrice: p.claimedPrice,
            oraclePrice: p.oraclePrice,
            priceDeviationBps: devBps,
            verifiedAt: uint64(block.timestamp)
        });

        emit VerificationFailed(intentId, esc.agent, p.failureCode);
        emit EscrowRefunded(intentId, esc.owner, esc.amount);
    }

    receive() external payable {}
}
