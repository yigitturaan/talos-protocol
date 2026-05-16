// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPolicyEngine} from "../interfaces/IPolicyEngine.sol";

/// @notice Restricts agent interactions to whitelisted contracts only.
contract ContractWhitelist is IPolicyEngine, Ownable {

    mapping(address => bool) private _allowed;

    event ContractAllowed(address indexed target, bool allowed);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setAllowed(address target, bool allowed) external onlyOwner {
        _allowed[target] = allowed;
        emit ContractAllowed(target, allowed);
    }

    function setAllowedBatch(address[] calldata targets, bool allowed) external onlyOwner {
        for (uint256 i; i < targets.length;) {
            _allowed[targets[i]] = allowed;
            emit ContractAllowed(targets[i], allowed);
            unchecked { ++i; }
        }
    }

    function isAllowed(address target) external view returns (bool) {
        return _allowed[target];
    }

    function check(
        bytes calldata,
        address,
        uint256,
        address targetContract
    ) external view returns (PolicyOutput memory) {
        if (targetContract == address(0)) {
            return PolicyOutput(PolicyResult.Allowed, "ContractWhitelist", "No target contract");
        }

        if (!_allowed[targetContract]) {
            return PolicyOutput(PolicyResult.Denied, "ContractWhitelist", "Contract not whitelisted");
        }

        return PolicyOutput(PolicyResult.Allowed, "ContractWhitelist", "Contract whitelisted");
    }
}
