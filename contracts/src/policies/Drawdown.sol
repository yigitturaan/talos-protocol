// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPolicyEngine} from "../interfaces/IPolicyEngine.sol";

/// @notice Kill-switch policy: denies all agent actions when portfolio value
///         has dropped more than maxDrawdownPct from its initial value.
contract Drawdown is IPolicyEngine, Ownable {

    uint8 public constant DEFAULT_MAX_DRAWDOWN_PCT = 20;

    struct DrawdownConfig {
        uint256 initialPortfolioValue;
        uint256 currentPortfolioValue;
        uint8 maxDrawdownPct;
    }

    mapping(address => DrawdownConfig) private _configs;

    event DrawdownConfigSet(address indexed agent, uint256 initialValue, uint8 maxDrawdownPct);
    event PortfolioValueUpdated(address indexed agent, uint256 newValue);

    error ZeroInitialValue();
    error ZeroDrawdownPct();
    error DrawdownPctTooHigh();

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setConfig(address agent, uint256 initialValue, uint8 maxDrawdownPct) external onlyOwner {
        if (initialValue == 0) revert ZeroInitialValue();
        if (maxDrawdownPct == 0) revert ZeroDrawdownPct();
        if (maxDrawdownPct > 100) revert DrawdownPctTooHigh();
        _configs[agent] = DrawdownConfig(initialValue, initialValue, maxDrawdownPct);
        emit DrawdownConfigSet(agent, initialValue, maxDrawdownPct);
    }

    function updatePortfolioValue(address agent, uint256 newValue) external onlyOwner {
        _configs[agent].currentPortfolioValue = newValue;
        emit PortfolioValueUpdated(agent, newValue);
    }

    function getConfig(address agent)
        external
        view
        returns (uint256 initialValue, uint256 currentValue, uint8 maxDrawdownPct)
    {
        DrawdownConfig memory c = _configs[agent];
        return (c.initialPortfolioValue, c.currentPortfolioValue, c.maxDrawdownPct);
    }

    function check(
        bytes calldata,
        address agent,
        uint256,
        address
    ) external view returns (PolicyOutput memory) {
        DrawdownConfig memory c = _configs[agent];

        if (c.initialPortfolioValue == 0) {
            return PolicyOutput(PolicyResult.Allowed, "Drawdown", "No config set");
        }

        // Drawdown triggered if currentValue < initialValue * (100 - maxDrawdownPct) / 100
        uint256 threshold = (c.initialPortfolioValue * (100 - c.maxDrawdownPct)) / 100;

        if (c.currentPortfolioValue < threshold) {
            return PolicyOutput(PolicyResult.Denied, "Drawdown", "Max drawdown exceeded");
        }

        return PolicyOutput(PolicyResult.Allowed, "Drawdown", "Within drawdown limit");
    }
}
