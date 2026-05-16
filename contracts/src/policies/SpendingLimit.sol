// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPolicyEngine} from "../interfaces/IPolicyEngine.sol";

/// @notice Per-agent daily/weekly spending limit policy.
///         Storage is keyed by agent address for parallel-execution safety.
contract SpendingLimit is IPolicyEngine, Ownable {

    struct Limits {
        uint256 dailyLimit;
        uint256 weeklyLimit;
    }

    struct SpendRecord {
        uint256 amount;
        uint64 timestamp;
    }

    mapping(address => Limits) private _limits;
    mapping(address => SpendRecord[]) private _history;

    event LimitsSet(address indexed agent, uint256 dailyLimit, uint256 weeklyLimit);

    error ZeroLimit();

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setLimits(address agent, uint256 dailyLimit, uint256 weeklyLimit) external onlyOwner {
        if (dailyLimit == 0 && weeklyLimit == 0) revert ZeroLimit();
        _limits[agent] = Limits(dailyLimit, weeklyLimit);
        emit LimitsSet(agent, dailyLimit, weeklyLimit);
    }

    function getLimits(address agent) external view returns (uint256 dailyLimit, uint256 weeklyLimit) {
        Limits memory l = _limits[agent];
        return (l.dailyLimit, l.weeklyLimit);
    }

    function getSpentInWindow(address agent, uint256 windowSeconds) external view returns (uint256 total) {
        uint256 cutoff = block.timestamp > windowSeconds ? block.timestamp - windowSeconds : 0;
        SpendRecord[] storage records = _history[agent];
        for (uint256 i = records.length; i > 0;) {
            unchecked { --i; }
            if (records[i].timestamp < cutoff) break;
            total += records[i].amount;
        }
    }

    function check(
        bytes calldata,
        address agent,
        uint256 amount,
        address
    ) external view returns (PolicyOutput memory) {
        Limits memory lim = _limits[agent];

        if (lim.dailyLimit == 0 && lim.weeklyLimit == 0) {
            return PolicyOutput(PolicyResult.Allowed, "SpendingLimit", "No limits configured");
        }

        if (lim.dailyLimit > 0) {
            uint256 dailySpent = _spentInWindow(agent, 1 days);
            if (dailySpent + amount > lim.dailyLimit) {
                return PolicyOutput(PolicyResult.Denied, "SpendingLimit", "Daily limit exceeded");
            }
        }

        if (lim.weeklyLimit > 0) {
            uint256 weeklySpent = _spentInWindow(agent, 7 days);
            if (weeklySpent + amount > lim.weeklyLimit) {
                return PolicyOutput(PolicyResult.Denied, "SpendingLimit", "Weekly limit exceeded");
            }
        }

        return PolicyOutput(PolicyResult.Allowed, "SpendingLimit", "Within limits");
    }

    function recordSpend(address agent, uint256 amount) external onlyOwner {
        _history[agent].push(SpendRecord(amount, uint64(block.timestamp)));
    }

    function _spentInWindow(address agent, uint256 windowSeconds) internal view returns (uint256 total) {
        uint256 cutoff = block.timestamp > windowSeconds ? block.timestamp - windowSeconds : 0;
        SpendRecord[] storage records = _history[agent];
        for (uint256 i = records.length; i > 0;) {
            unchecked { --i; }
            if (records[i].timestamp < cutoff) break;
            total += records[i].amount;
        }
    }
}
