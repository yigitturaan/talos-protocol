// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ═══════════════════════════════════════════════════════
//  Minimal Uniswap V4 interfaces (inline — no external dep)
//  Source: https://developers.uniswap.org/contracts/v4
// ═══════════════════════════════════════════════════════

type Currency is address;

struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/// @notice Parameters for a single-pool exact-input swap.
struct SwapParams {
    address inputToken;
    address outputToken;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
    uint256 amountIn;
    uint256 minAmountOut;
    address recipient;
}

/// @notice Adapter for executing swaps through Uniswap V4 Universal Router on Monad.
///         Encoding: V4_SWAP (0x10) → SWAP_EXACT_IN_SINGLE + SETTLE_ALL + TAKE_ALL.
contract UniswapV4Adapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable universalRouter;
    address public immutable permit2;
    address public immutable poolManager;

    uint8 private constant CMD_V4_SWAP = 0x10;
    uint8 private constant ACTION_SWAP_EXACT_IN_SINGLE = 0x06;
    uint8 private constant ACTION_SETTLE_ALL = 0x0c;
    uint8 private constant ACTION_TAKE_ALL = 0x0f;

    uint256 private constant SWAP_DEADLINE_OFFSET = 300;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientOutput(uint256 received, uint256 minRequired);

    event SwapExecuted(
        address indexed inputToken,
        address indexed outputToken,
        uint256 amountIn,
        uint256 amountOut,
        address recipient
    );

    constructor(address _universalRouter, address _permit2, address _poolManager) {
        if (_universalRouter == address(0) || _permit2 == address(0) || _poolManager == address(0)) {
            revert ZeroAddress();
        }
        universalRouter = _universalRouter;
        permit2 = _permit2;
        poolManager = _poolManager;
    }

    /// @notice Execute a single-pool exact-input swap via Uniswap V4.
    function swap(SwapParams calldata p) external nonReentrant returns (uint256 amountOut) {
        if (p.amountIn == 0) revert ZeroAmount();

        _approveIfNeeded(p.inputToken, p.amountIn);

        (bytes memory commands, bytes[] memory inputs) = _encodeSwap(p);
        uint256 deadline = block.timestamp + SWAP_DEADLINE_OFFSET;

        // Snapshot adapter's output balance (TAKE_ALL sends to msg.sender = this adapter)
        uint256 adapterBalBefore = _balanceOf(p.outputToken, address(this));

        if (p.inputToken == address(0)) {
            IUniversalRouter(universalRouter).execute{value: p.amountIn}(commands, inputs, deadline);
        } else {
            IUniversalRouter(universalRouter).execute(commands, inputs, deadline);
        }

        amountOut = _balanceOf(p.outputToken, address(this)) - adapterBalBefore;
        if (amountOut < p.minAmountOut) revert InsufficientOutput(amountOut, p.minAmountOut);

        // Forward output to recipient
        _transfer(p.outputToken, p.recipient, amountOut);

        emit SwapExecuted(p.inputToken, p.outputToken, p.amountIn, amountOut, p.recipient);
    }

    function _approveIfNeeded(address token, uint256 amount) internal {
        if (token == address(0)) return;
        IERC20(token).safeIncreaseAllowance(permit2, amount);
        IPermit2(permit2).approve(
            token,
            universalRouter,
            uint160(amount),
            uint48(block.timestamp + SWAP_DEADLINE_OFFSET)
        );
    }

    function _encodeSwap(SwapParams calldata p)
        internal
        pure
        returns (bytes memory commands, bytes[] memory inputs)
    {
        (Currency c0, Currency c1, bool zeroForOne) = _sortCurrencies(p.inputToken, p.outputToken);

        PoolKey memory key = PoolKey(c0, c1, p.fee, p.tickSpacing, p.hooks);

        bytes memory actions = abi.encodePacked(
            ACTION_SWAP_EXACT_IN_SINGLE,
            ACTION_SETTLE_ALL,
            ACTION_TAKE_ALL
        );

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            key,
            zeroForOne,
            uint128(p.amountIn),
            uint128(p.minAmountOut),
            uint256(0),
            bytes("")
        );

        Currency inputCurrency = zeroForOne ? c0 : c1;
        Currency outputCurrency = zeroForOne ? c1 : c0;
        params[1] = abi.encode(inputCurrency, p.amountIn);
        params[2] = abi.encode(outputCurrency, p.minAmountOut);

        commands = abi.encodePacked(CMD_V4_SWAP);
        inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
    }

    function _balanceOf(address token, address account) internal view returns (uint256) {
        if (token == address(0)) return account.balance;
        return IERC20(token).balanceOf(account);
    }

    error NativeTransferFailed();

    function _transfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert NativeTransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _sortCurrencies(address tokenA, address tokenB)
        internal
        pure
        returns (Currency currency0, Currency currency1, bool zeroForOne)
    {
        if (tokenA < tokenB) {
            return (Currency.wrap(tokenA), Currency.wrap(tokenB), true);
        } else {
            return (Currency.wrap(tokenB), Currency.wrap(tokenA), false);
        }
    }

    receive() external payable {}
}
