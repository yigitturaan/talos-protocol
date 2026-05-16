// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPolicyEngine} from "../interfaces/IPolicyEngine.sol";
import {AgentClaim} from "../types/TalosTypes.sol";
import {ClaimEncoder} from "../libraries/ClaimEncoder.sol";

/// @notice Checks that the agent's expectedOutputMin is not worse than maxSlippageBps
///         relative to the current market price of the output token.
///         Market price is provided externally (set by protocol owner via setMarketPrice).
contract SlippageGuard is IPolicyEngine, Ownable {
    using ClaimEncoder for AgentClaim;

    uint16 public constant DEFAULT_MAX_SLIPPAGE_BPS = 200;

    struct SlippageConfig {
        uint16 maxSlippageBps;
    }

    mapping(address => SlippageConfig) private _configs;

    // token => current market price (8 decimals, same scale as AgentClaim.claimedPrice)
    mapping(address => uint256) private _marketPrices;

    event SlippageConfigSet(address indexed agent, uint16 maxSlippageBps);
    event MarketPriceUpdated(address indexed token, uint256 price);

    error ZeroSlippageBps();
    error ZeroMarketPrice();

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setConfig(address agent, uint16 maxSlippageBps) external onlyOwner {
        if (maxSlippageBps == 0) revert ZeroSlippageBps();
        _configs[agent] = SlippageConfig(maxSlippageBps);
        emit SlippageConfigSet(agent, maxSlippageBps);
    }

    function getConfig(address agent) external view returns (uint16 maxSlippageBps) {
        uint16 bps = _configs[agent].maxSlippageBps;
        return bps == 0 ? DEFAULT_MAX_SLIPPAGE_BPS : bps;
    }

    function setMarketPrice(address token, uint256 price) external onlyOwner {
        if (price == 0) revert ZeroMarketPrice();
        _marketPrices[token] = price;
        emit MarketPriceUpdated(token, price);
    }

    function getMarketPrice(address token) external view returns (uint256) {
        return _marketPrices[token];
    }

    function check(
        bytes calldata claimData,
        address agent,
        uint256 amount,
        address
    ) external view returns (PolicyOutput memory) {
        if (amount == 0) {
            return PolicyOutput(PolicyResult.Allowed, "SlippageGuard", "Zero amount");
        }

        AgentClaim memory claim = ClaimEncoder.decode(claimData);

        uint256 marketPrice = _marketPrices[claim.priceFeed];
        if (marketPrice == 0) {
            return PolicyOutput(PolicyResult.Allowed, "SlippageGuard", "No market price set");
        }

        // Expected fair output at market price for the given amount
        // fairOutput = amount * marketPrice / claimedPrice (if buying the output token)
        // But expectedOutputMin is what the agent says they'll get at minimum.
        // We compare: expectedOutputMin >= fairOutput * (10000 - maxSlippageBps) / 10000
        //
        // Simplified: check that expectedOutputMin is not worse than maxSlippageBps
        // below the fair value. fairOutput = amount * marketPrice / 1e8 (normalized)
        uint256 fairOutput = (amount * marketPrice) / 1e8;

        uint16 maxBps = _configs[agent].maxSlippageBps;
        if (maxBps == 0) maxBps = DEFAULT_MAX_SLIPPAGE_BPS;

        uint256 minAcceptable = (fairOutput * (10000 - maxBps)) / 10000;

        if (claim.expectedOutputMin < minAcceptable) {
            return PolicyOutput(PolicyResult.Denied, "SlippageGuard", "Slippage exceeds maximum");
        }

        return PolicyOutput(PolicyResult.Allowed, "SlippageGuard", "Within slippage tolerance");
    }
}
