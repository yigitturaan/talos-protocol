// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {AgentClaim} from "../types/TalosTypes.sol";
import {ClaimEncoder} from "../libraries/ClaimEncoder.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice Chainlink price verification with 3-tier graduated tolerance.
///         Section 8 of project doc — no mocks, real oracle calls only.
contract PriceVerifier is IVerifier {
    using ClaimEncoder for bytes;

    uint16 public constant SOFT_TOLERANCE_BPS = 150;  // 1.5%
    uint16 public constant HARD_TOLERANCE_BPS = 500;  // 5.0%
    uint256 public constant STALENESS_SECONDS = 3600;
    uint8 public constant CLAIM_DECIMALS = 8;

    error StaleOracleData(uint256 updatedAt, uint256 maxAge);
    error InvalidOracleAnswer();
    error StaleRound(uint80 answeredInRound, uint80 roundId);

    function verify(
        bytes calldata claimData,
        address[] calldata references
    ) external view override returns (VerificationOutput memory) {
        AgentClaim memory claim = ClaimEncoder.decode(claimData);

        // Feed mismatch: agent must reference the same oracle passed in references[0]
        if (claim.priceFeed != references[0]) {
            return VerificationOutput({
                result: VerificationResult.HardReject,
                deviationBps: 10000,
                reason: "Feed mismatch: claim.priceFeed != references[0]"
            });
        }

        AggregatorV3Interface feed = AggregatorV3Interface(references[0]);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        // Oracle sanity: negative or zero price
        if (answer <= 0) {
            return VerificationOutput({
                result: VerificationResult.HardReject,
                deviationBps: 10000,
                reason: "Oracle returned non-positive price"
            });
        }

        // Staleness check
        if (updatedAt == 0 || block.timestamp - updatedAt > STALENESS_SECONDS) {
            revert StaleOracleData(updatedAt, STALENESS_SECONDS);
        }

        // Round completeness
        if (answeredInRound < roundId) {
            revert StaleRound(answeredInRound, roundId);
        }

        uint256 oraclePrice = uint256(answer);
        uint8 feedDecimals = feed.decimals();

        // Normalize both prices to the same decimal base for comparison.
        // claimedPrice is in CLAIM_DECIMALS (8). Oracle is in feedDecimals.
        // Scale the lower-decimal value UP to match the higher.
        uint256 normalizedClaimed;
        uint256 normalizedOracle;

        if (feedDecimals >= CLAIM_DECIMALS) {
            uint256 scale = 10 ** (feedDecimals - CLAIM_DECIMALS);
            normalizedClaimed = claim.claimedPrice * scale;
            normalizedOracle = oraclePrice;
        } else {
            uint256 scale = 10 ** (CLAIM_DECIMALS - feedDecimals);
            normalizedClaimed = claim.claimedPrice;
            normalizedOracle = oraclePrice * scale;
        }

        // Deviation in basis points
        uint256 diff = normalizedClaimed > normalizedOracle
            ? normalizedClaimed - normalizedOracle
            : normalizedOracle - normalizedClaimed;

        uint16 deviationBps;
        if (normalizedOracle > 0) {
            deviationBps = uint16((diff * 10000) / normalizedOracle);
        } else {
            deviationBps = 10000;
        }

        // 3-tier graduated tolerance (Section 8)
        if (deviationBps <= SOFT_TOLERANCE_BPS) {
            return VerificationOutput({
                result: VerificationResult.Passed,
                deviationBps: deviationBps,
                reason: ""
            });
        } else if (deviationBps <= HARD_TOLERANCE_BPS) {
            return VerificationOutput({
                result: VerificationResult.SoftReject,
                deviationBps: deviationBps,
                reason: "Price drift in gray zone - retry recommended"
            });
        } else {
            return VerificationOutput({
                result: VerificationResult.HardReject,
                deviationBps: deviationBps,
                reason: "Price mismatch exceeds hard tolerance"
            });
        }
    }
}
