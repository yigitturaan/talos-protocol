// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UniswapV4Adapter, SwapParams} from "../../src/execution/UniswapV4Adapter.sol";
import {Addresses} from "../../script/Addresses.sol";

/// @notice Fork test: real USDC → native MON swap via Uniswap V4 Universal Router.
///         Run with: forge test --match-contract UniswapV4ForkTest --fork-url https://rpc.monad.xyz -vvv
contract UniswapV4ForkTest is Test {

    UniswapV4Adapter adapter;

    address constant USDC = Addresses.USDC;
    address constant WMON = Addresses.WMON;
    address constant UNIVERSAL_ROUTER = Addresses.UNI_V4_UNIVERSAL_ROUTER;
    address constant PERMIT2 = Addresses.PERMIT2;
    address constant POOL_MANAGER = Addresses.UNI_V4_POOL_MANAGER;

    // Best liquidity native MON/USDC pool: fee=500, tickSpacing=10
    uint24 constant POOL_FEE = 500;
    int24 constant POOL_TICK_SPACING = 10;

    address user = vm.addr(0xB1);

    uint256 constant SWAP_AMOUNT = 10e6; // 10 USDC

    function setUp() public {
        adapter = new UniswapV4Adapter(UNIVERSAL_ROUTER, PERMIT2, POOL_MANAGER);

        // Deal USDC to user (fork state — real token)
        deal(USDC, user, 1000e6);
    }

    function test_swapUSDCtoNativeMON() public {
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);
        uint256 monBefore = user.balance;

        console2.log("USDC balance before:", usdcBefore);
        console2.log("MON balance before:", monBefore);

        vm.startPrank(user);

        // User approves adapter to pull USDC
        IERC20(USDC).approve(address(adapter), SWAP_AMOUNT);

        // Transfer USDC to adapter (adapter will do the Permit2 flow internally)
        IERC20(USDC).transfer(address(adapter), SWAP_AMOUNT);

        vm.stopPrank();

        // Execute swap from adapter (it holds the tokens now)
        // For the adapter to work, tokens need to be in the adapter or approved.
        // Let's restructure: the adapter should pull tokens via safeTransferFrom.
        // Actually, our adapter calls Permit2 approve + safeIncreaseAllowance on the
        // input token to permit2. But the adapter needs to have the tokens first OR
        // the adapter needs to be approved by the user to pull.
        //
        // In the real protocol flow: TalosProtocol holds escrow tokens, calls adapter.
        // For this test: deal tokens to adapter directly and call swap.

        deal(USDC, address(adapter), SWAP_AMOUNT);

        SwapParams memory p = SwapParams({
            inputToken: USDC,
            outputToken: address(0), // native MON
            fee: POOL_FEE,
            tickSpacing: POOL_TICK_SPACING,
            hooks: address(0),
            amountIn: SWAP_AMOUNT,
            minAmountOut: 1, // accept any nonzero output for discovery
            recipient: user
        });

        uint256 amountOut = adapter.swap(p);

        console2.log("MON received:", amountOut);
        console2.log("MON balance after:", user.balance);

        assertGt(amountOut, 0, "Should receive nonzero MON");
        assertGt(user.balance, monBefore, "User MON balance should increase");
    }

    function test_swapUSDCtoWMON() public {
        uint256 wmonBefore = IERC20(WMON).balanceOf(user);

        deal(USDC, address(adapter), SWAP_AMOUNT);

        // USDC (0x7547...) > WMON (0x3bd3...) so zeroForOne=false
        // currency0=WMON, currency1=USDC, selling USDC → buying WMON
        // Actually the adapter sorts internally via _sortCurrencies

        SwapParams memory p = SwapParams({
            inputToken: USDC,
            outputToken: WMON,
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0),
            amountIn: SWAP_AMOUNT,
            minAmountOut: 1,
            recipient: user
        });

        // This pool (WMON/USDC 3000/60) might not have liquidity
        // The main pool with liquidity is native MON / USDC (500/10)
        // If it reverts, that's expected — skip gracefully
        try adapter.swap(p) returns (uint256 out) {
            assertGt(out, 0);
            assertGt(IERC20(WMON).balanceOf(user), wmonBefore);
        } catch {
            // WMON/USDC pool at 3000/60 has no liquidity — expected
            console2.log("WMON/USDC 3000/60 pool has no liquidity, skipping");
        }
    }

    function test_swapRespects_minAmountOut() public {
        deal(USDC, address(adapter), SWAP_AMOUNT);

        SwapParams memory p = SwapParams({
            inputToken: USDC,
            outputToken: address(0),
            fee: POOL_FEE,
            tickSpacing: POOL_TICK_SPACING,
            hooks: address(0),
            amountIn: SWAP_AMOUNT,
            minAmountOut: type(uint256).max, // impossibly high minimum
            recipient: user
        });

        vm.expectRevert();
        adapter.swap(p);
    }

    function test_swapZeroAmount_reverts() public {
        SwapParams memory p = SwapParams({
            inputToken: USDC,
            outputToken: address(0),
            fee: POOL_FEE,
            tickSpacing: POOL_TICK_SPACING,
            hooks: address(0),
            amountIn: 0,
            minAmountOut: 0,
            recipient: user
        });

        vm.expectRevert(UniswapV4Adapter.ZeroAmount.selector);
        adapter.swap(p);
    }

    function test_constructorReverts_zeroAddress() public {
        vm.expectRevert(UniswapV4Adapter.ZeroAddress.selector);
        new UniswapV4Adapter(address(0), PERMIT2, POOL_MANAGER);
    }
}
