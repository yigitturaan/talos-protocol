// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVerifier} from "../interfaces/IVerifier.sol";

/// @notice General-purpose on-chain state verification via staticcall.
///         references[0] = target contract.
///         claimData = abi.encode(bytes4 selector, bytes callArgs,
///                                uint256 claimedValue, uint16 toleranceBps).
///         Use case: Morpho vault share price, pool reserves, any view
///         function returning uint256. Reentrancy-safe (view-only staticcall).
contract StateVerifier is IVerifier {

    function verify(
        bytes calldata claimData,
        address[] calldata references
    ) external view override returns (VerificationOutput memory) {
        address target = references[0];

        (
            bytes4 selector,
            bytes memory callArgs,
            uint256 claimedValue,
            uint16 toleranceBps
        ) = abi.decode(claimData, (bytes4, bytes, uint256, uint16));

        (bool success, bytes memory returnData) = target.staticcall(
            bytes.concat(selector, callArgs)
        );

        if (!success || returnData.length < 32) {
            return VerificationOutput({
                result: VerificationResult.HardReject,
                deviationBps: 10000,
                reason: "staticcall failed or invalid return"
            });
        }

        uint256 actualValue = abi.decode(returnData, (uint256));

        if (actualValue == claimedValue) {
            return VerificationOutput({
                result: VerificationResult.Passed,
                deviationBps: 0,
                reason: ""
            });
        }

        uint256 diff = actualValue > claimedValue
            ? actualValue - claimedValue
            : claimedValue - actualValue;

        uint256 rawDeviation;
        if (actualValue > 0) {
            rawDeviation = (diff * 10000) / actualValue;
            if (rawDeviation > 10000) rawDeviation = 10000;
        } else {
            rawDeviation = 10000;
        }

        // safe: rawDeviation capped at 10000, fits uint16
        uint16 deviationBps = uint16(rawDeviation);

        if (deviationBps <= toleranceBps) {
            return VerificationOutput({
                result: VerificationResult.Passed,
                deviationBps: deviationBps,
                reason: ""
            });
        }

        return VerificationOutput({
            result: VerificationResult.HardReject,
            deviationBps: deviationBps,
            reason: "State value exceeds tolerance"
        });
    }
}
