// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SwapParams} from "../execution/UniswapV4Adapter.sol";

/// @notice Testnet-only swap adapter. Passes input tokens directly to recipient
///         (1:1 passthrough) so the full CVE pipeline can be demonstrated without
///         requiring a live Uniswap V4 deployment.
contract DemoSwapAdapter {
    using SafeERC20 for IERC20;

    event DemoSwap(address indexed inputToken, uint256 amountIn, address recipient);

    function swap(SwapParams calldata p) external returns (uint256 amountOut) {
        IERC20(p.inputToken).safeTransferFrom(msg.sender, p.recipient, p.amountIn);
        emit DemoSwap(p.inputToken, p.amountIn, p.recipient);
        return p.amountIn;
    }

    receive() external payable {}
}
