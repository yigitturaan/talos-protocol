// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AgentClaim} from "../src/types/TalosTypes.sol";
import {ClaimEncoder} from "../src/libraries/ClaimEncoder.sol";

contract ClaimEncoderTest is Test {
    using ClaimEncoder for AgentClaim;

    function _goldenClaim() internal pure returns (AgentClaim memory) {
        return AgentClaim({
            priceFeed: 0xFB504aD06Ab5E6c63FE0A46FEa245214838E8015,
            claimedPrice: 3_800_000_000,
            reasoning: "RSI 28.4 < 30 threshold, buy signal",
            action: "BUY_MON",
            protocol: 0x0D97Dc33264bfC1c226207428A79b26757fb9dc3,
            expectedOutputMin: 260 ether,
            timestamp: 1747310400,
            expiry: 1747310460
        });
    }

    function test_encode_decode_roundtrip() public pure {
        AgentClaim memory original = _goldenClaim();
        bytes memory encoded = original.encode();
        AgentClaim memory decoded = ClaimEncoder.decode(encoded);

        assertEq(decoded.priceFeed, original.priceFeed);
        assertEq(decoded.claimedPrice, original.claimedPrice);
        assertEq(decoded.reasoning, original.reasoning);
        assertEq(decoded.action, original.action);
        assertEq(decoded.protocol, original.protocol);
        assertEq(decoded.expectedOutputMin, original.expectedOutputMin);
        assertEq(decoded.timestamp, original.timestamp);
        assertEq(decoded.expiry, original.expiry);
    }

    function test_hash_deterministic() public pure {
        AgentClaim memory claim = _goldenClaim();
        bytes32 h1 = claim.hash();
        bytes32 h2 = claim.hash();
        assertEq(h1, h2);
    }

    function test_hash_golden_value() public {
        AgentClaim memory claim = _goldenClaim();
        bytes32 h = claim.hash();

        // Log golden hash for SDK parity test
        emit log_named_bytes32("GOLDEN_HASH", h);

        // The hash must be stable — computed once, hardcoded forever.
        // SDK (viem encodeAbiParameters) must produce this exact hash.
        bytes32 expected = keccak256(
            abi.encode(
                address(0xFB504aD06Ab5E6c63FE0A46FEa245214838E8015),
                uint256(3_800_000_000),
                "RSI 28.4 < 30 threshold, buy signal",
                "BUY_MON",
                address(0x0D97Dc33264bfC1c226207428A79b26757fb9dc3),
                uint256(260 ether),
                uint64(1747310400),
                uint64(1747310460)
            )
        );
        assertEq(h, expected, "ClaimEncoder.hash must match manual abi.encode + keccak256");
    }

    function test_different_claim_different_hash() public pure {
        AgentClaim memory c1 = _goldenClaim();
        AgentClaim memory c2 = _goldenClaim();
        c2.claimedPrice = 2_500_000_000;
        assertTrue(c1.hash() != c2.hash());
    }

    function testFuzz_encode_decode(
        uint256 price,
        uint256 outputMin,
        uint64 ts,
        uint64 exp
    ) public pure {
        AgentClaim memory claim = AgentClaim({
            priceFeed: address(1),
            claimedPrice: price,
            reasoning: "fuzz",
            action: "TEST",
            protocol: address(2),
            expectedOutputMin: outputMin,
            timestamp: ts,
            expiry: exp
        });

        AgentClaim memory decoded = ClaimEncoder.decode(claim.encode());
        assertEq(decoded.claimedPrice, price);
        assertEq(decoded.expectedOutputMin, outputMin);
        assertEq(decoded.timestamp, ts);
        assertEq(decoded.expiry, exp);
    }
}
