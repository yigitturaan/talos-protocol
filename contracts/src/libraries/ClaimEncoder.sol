// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AgentClaim} from "../types/TalosTypes.sol";

/// @notice Deterministic ABI encoding for AgentClaim.
///         SDK (viem encodeAbiParameters) must produce byte-identical output.
library ClaimEncoder {
    function encode(AgentClaim memory claim) internal pure returns (bytes memory) {
        return abi.encode(
            claim.priceFeed,
            claim.claimedPrice,
            claim.reasoning,
            claim.action,
            claim.protocol,
            claim.expectedOutputMin,
            claim.timestamp,
            claim.expiry
        );
    }

    function hash(AgentClaim memory claim) internal pure returns (bytes32) {
        return keccak256(encode(claim));
    }

    function decode(bytes memory data) internal pure returns (AgentClaim memory) {
        (
            address priceFeed,
            uint256 claimedPrice,
            string memory reasoning,
            string memory action,
            address protocol,
            uint256 expectedOutputMin,
            uint64 timestamp,
            uint64 expiry
        ) = abi.decode(data, (address, uint256, string, string, address, uint256, uint64, uint64));

        return AgentClaim({
            priceFeed: priceFeed,
            claimedPrice: claimedPrice,
            reasoning: reasoning,
            action: action,
            protocol: protocol,
            expectedOutputMin: expectedOutputMin,
            timestamp: timestamp,
            expiry: expiry
        });
    }
}
