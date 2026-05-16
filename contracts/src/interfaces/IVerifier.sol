// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Interface for modular verifiers (PriceVerifier, BalanceVerifier, StateVerifier).
interface IVerifier {
    enum VerificationResult {
        Passed,
        SoftReject,
        HardReject
    }

    struct VerificationOutput {
        VerificationResult result;
        uint16 deviationBps;
        string reason;
    }

    function verify(
        bytes calldata claimData,
        address[] calldata references
    ) external view returns (VerificationOutput memory);
}
