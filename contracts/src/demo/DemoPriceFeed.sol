// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Testnet-only Chainlink AggregatorV3-compatible price feed.
///         Provides controlled prices for demo/hackathon scenarios where
///         Chainlink feeds are not yet deployed on-chain.
contract DemoPriceFeed {
    uint8 public constant decimals = 8;
    string public description;

    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId;
    address public immutable owner;

    constructor(int256 initialPrice, string memory desc) {
        owner = msg.sender;
        _price = initialPrice;
        _updatedAt = block.timestamp;
        _roundId = 1;
        description = desc;
    }

    function setPrice(int256 newPrice) external {
        require(msg.sender == owner, "not owner");
        _price = newPrice;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}
