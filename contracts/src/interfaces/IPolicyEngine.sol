// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Interface for modular policy engines (SpendingLimit, ContractWhitelist, SlippageGuard, Drawdown).
interface IPolicyEngine {
    enum PolicyResult {
        Allowed,
        Denied
    }

    struct PolicyOutput {
        PolicyResult result;
        string policy;
        string reason;
    }

    function check(
        bytes calldata claimData,
        address agent,
        uint256 amount,
        address targetContract
    ) external view returns (PolicyOutput memory);
}
