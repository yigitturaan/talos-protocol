// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {PriceVerifier} from "../src/verifiers/PriceVerifier.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {AgentClaim} from "../src/types/TalosTypes.sol";
import {ClaimEncoder} from "../src/libraries/ClaimEncoder.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice Fork tests against real Monad mainnet Chainlink feeds.
///         Run: forge test --match-contract PriceVerifierTest --fork-url https://rpc.monad.xyz -vvv
contract PriceVerifierTest is Test {
    using ClaimEncoder for AgentClaim;

    PriceVerifier verifier;

    // Real Chainlink feed addresses on Monad mainnet (chain 143)
    address constant MON_USD_FEED = 0xFB504aD06Ab5E6c63FE0A46FEa245214838E8015;
    address constant ETH_USD_FEED = 0x1B1414782B859871781bA3E4B0979b9ca57A0A04;

    function setUp() public {
        verifier = new PriceVerifier();
    }

    // ═══════════════════════════════════════════
    //  Helper: build a claim and encode it
    // ═══════════════════════════════════════════

    function _buildClaim(
        address feed,
        uint256 claimedPrice
    ) internal view returns (bytes memory) {
        AgentClaim memory claim = AgentClaim({
            priceFeed: feed,
            claimedPrice: claimedPrice,
            reasoning: "test claim",
            action: "swap",
            protocol: address(0xdead),
            expectedOutputMin: 0,
            timestamp: uint64(block.timestamp),
            expiry: uint64(block.timestamp + 3600)
        });
        return ClaimEncoder.encode(claim);
    }

    function _refs(address feed) internal pure returns (address[] memory) {
        address[] memory refs = new address[](1);
        refs[0] = feed;
        return refs;
    }

    // ═══════════════════════════════════════════
    //  Live oracle: exact price → Passed
    // ═══════════════════════════════════════════

    function test_liveOracle_exactPrice_passed() public {
        AggregatorV3Interface feed = AggregatorV3Interface(MON_USD_FEED);
        (, int256 answer,,,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        console2.log("MON/USD live price (raw):", uint256(answer));
        console2.log("MON/USD feed decimals:", feedDecimals);

        // Convert oracle price to CLAIM_DECIMALS (8) for the claim
        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        bytes memory claimData = _buildClaim(MON_USD_FEED, claimedPrice);
        IVerifier.VerificationOutput memory out = verifier.verify(claimData, _refs(MON_USD_FEED));

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertLe(out.deviationBps, 150);
    }

    // ═══════════════════════════════════════════
    //  Live oracle: ~2% deviation → SoftReject
    // ═══════════════════════════════════════════

    function test_liveOracle_softDeviation_softReject() public {
        AggregatorV3Interface feed = AggregatorV3Interface(MON_USD_FEED);
        (, int256 answer,,,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        // Add ~2% deviation (inside gray zone: 1.5% < 2% < 5%)
        claimedPrice = claimedPrice * 102 / 100;

        bytes memory claimData = _buildClaim(MON_USD_FEED, claimedPrice);
        IVerifier.VerificationOutput memory out = verifier.verify(claimData, _refs(MON_USD_FEED));

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.SoftReject));
        assertGt(out.deviationBps, 150);
        assertLe(out.deviationBps, 500);
    }

    // ═══════════════════════════════════════════
    //  Live oracle: ~10% deviation → HardReject
    // ═══════════════════════════════════════════

    function test_liveOracle_hardDeviation_hardReject() public {
        AggregatorV3Interface feed = AggregatorV3Interface(MON_USD_FEED);
        (, int256 answer,,,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        // Add ~10% deviation (exceeds hard tolerance of 5%)
        claimedPrice = claimedPrice * 110 / 100;

        bytes memory claimData = _buildClaim(MON_USD_FEED, claimedPrice);
        IVerifier.VerificationOutput memory out = verifier.verify(claimData, _refs(MON_USD_FEED));

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertGt(out.deviationBps, 500);
    }

    // ═══════════════════════════════════════════
    //  Feed mismatch → HardReject
    // ═══════════════════════════════════════════

    function test_feedMismatch_hardReject() public {
        AggregatorV3Interface feed = AggregatorV3Interface(MON_USD_FEED);
        (, int256 answer,,,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        // Claim says MON_USD_FEED but references[0] is ETH_USD_FEED
        bytes memory claimData = _buildClaim(MON_USD_FEED, claimedPrice);
        IVerifier.VerificationOutput memory out = verifier.verify(claimData, _refs(ETH_USD_FEED));

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertEq(out.deviationBps, 10000);
    }

    // ═══════════════════════════════════════════
    //  Stale oracle data → revert
    // ═══════════════════════════════════════════

    function test_staleData_reverts() public {
        AggregatorV3Interface feed = AggregatorV3Interface(MON_USD_FEED);
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        // Warp time forward so the feed data becomes stale (> 3600s)
        vm.warp(updatedAt + 3601);

        bytes memory claimData = _buildClaim(MON_USD_FEED, claimedPrice);

        vm.expectRevert(
            abi.encodeWithSelector(
                PriceVerifier.StaleOracleData.selector,
                updatedAt,
                3600
            )
        );
        verifier.verify(claimData, _refs(MON_USD_FEED));
    }

    // ═══════════════════════════════════════════
    //  ETH/USD feed (8 decimals) — Passed
    // ═══════════════════════════════════════════

    function test_liveOracle_ethUsd_8dec_passed() public {
        AggregatorV3Interface feed = AggregatorV3Interface(ETH_USD_FEED);
        (, int256 answer,,,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        console2.log("ETH/USD live price (raw):", uint256(answer));
        console2.log("ETH/USD feed decimals:", feedDecimals);

        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        bytes memory claimData = _buildClaim(ETH_USD_FEED, claimedPrice);
        IVerifier.VerificationOutput memory out = verifier.verify(claimData, _refs(ETH_USD_FEED));

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertLe(out.deviationBps, 150);
    }

    // ═══════════════════════════════════════════
    //  Negative deviation (claimed < oracle) → SoftReject
    // ═══════════════════════════════════════════

    function test_liveOracle_underpriced_softReject() public {
        AggregatorV3Interface feed = AggregatorV3Interface(MON_USD_FEED);
        (, int256 answer,,,) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals();

        uint256 claimedPrice;
        if (feedDecimals >= 8) {
            claimedPrice = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            claimedPrice = uint256(answer) * (10 ** (8 - feedDecimals));
        }

        // Subtract ~3% (inside gray zone)
        claimedPrice = claimedPrice * 97 / 100;

        bytes memory claimData = _buildClaim(MON_USD_FEED, claimedPrice);
        IVerifier.VerificationOutput memory out = verifier.verify(claimData, _refs(MON_USD_FEED));

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.SoftReject));
        assertGt(out.deviationBps, 150);
        assertLe(out.deviationBps, 500);
    }
}
