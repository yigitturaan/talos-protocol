// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Testnet-only deposit adapter. Forwards tokens directly to receiver
///         (1:1 passthrough) so the full CVE pipeline can be demonstrated without
///         requiring a live Morpho/ERC-4626 deployment.
contract DemoDepositAdapter {
    using SafeERC20 for IERC20;

    event DemoDeposit(address indexed token, uint256 amount, address receiver);

    function deposit(
        address,
        address token,
        uint256 amount,
        uint256,
        address receiver
    ) external returns (uint256) {
        IERC20(token).safeTransfer(receiver, amount);
        emit DemoDeposit(token, amount, receiver);
        return amount;
    }
}
