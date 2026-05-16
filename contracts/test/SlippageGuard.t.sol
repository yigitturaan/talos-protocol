// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SlippageGuard} from "../src/policies/SlippageGuard.sol";
import {IPolicyEngine} from "../src/interfaces/IPolicyEngine.sol";
import {AgentClaim} from "../src/types/TalosTypes.sol";
import {ClaimEncoder} from "../src/libraries/ClaimEncoder.sol";

contract SlippageGuardTest is Test {
    using ClaimEncoder for AgentClaim;

    SlippageGuard guard;

    address deployer = address(this);
    address agent = vm.addr(0xA1);
    address priceFeed = vm.addr(0xF1);

    function setUp() public {
        guard = new SlippageGuard(deployer);
        // Set market price for priceFeed token: 100e8 (100 USD, 8 decimals)
        guard.setMarketPrice(priceFeed, 100e8);
    }

    function _buildClaim(uint256 expectedOutputMin) internal view returns (bytes memory) {
        AgentClaim memory claim = AgentClaim({
            priceFeed: priceFeed,
            claimedPrice: 100e8,
            reasoning: "test",
            action: "SWAP",
            protocol: vm.addr(0xBB),
            expectedOutputMin: expectedOutputMin,
            timestamp: uint64(block.timestamp),
            expiry: uint64(block.timestamp + 1 hours)
        });
        return claim.encode();
    }

    // ═══════════════════════════════════════════
    //  Default config (200 bps = 2%)
    // ═══════════════════════════════════════════

    function test_withinSlippage_allowed() public view {
        // amount=1000e6, fairOutput=1000e6*100e8/1e8=1000e6*100=100_000e6
        // minAcceptable at 2%: 100_000e6 * 9800/10000 = 98_000e6
        // expectedOutputMin=99_000e6 > 98_000e6 → Allowed
        bytes memory claimData = _buildClaim(99_000e6);
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_exactSlippageBoundary_allowed() public view {
        // minAcceptable at 2%: 98_000e6. expectedOutputMin=98_000e6 → Allowed (equal)
        bytes memory claimData = _buildClaim(98_000e6);
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_slippageExceedsMax_denied() public view {
        // minAcceptable at 2%: 98_000e6. expectedOutputMin=97_999e6 → Denied
        bytes memory claimData = _buildClaim(97_999e6);
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
        assertEq(out.policy, "SlippageGuard");
        assertEq(out.reason, "Slippage exceeds maximum");
    }

    // ═══════════════════════════════════════════
    //  Custom config (%1 = 100 bps)
    // ═══════════════════════════════════════════

    function test_customConfig_199bps_allowed() public {
        guard.setConfig(agent, 100); // 1%
        // fairOutput=100_000e6, minAcceptable at 1%: 99_000e6
        // expectedOutputMin=99_010e6 → Allowed (slightly above 1%)
        bytes memory claimData = _buildClaim(99_010e6);
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_customConfig_201bps_denied() public {
        guard.setConfig(agent, 100); // 1%
        // fairOutput=100_000e6, minAcceptable at 1%: 99_000e6
        // expectedOutputMin=98_900e6 → Denied (worse than 1%)
        bytes memory claimData = _buildClaim(98_900e6);
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
    }

    // ═══════════════════════════════════════════
    //  Edge cases
    // ═══════════════════════════════════════════

    function test_zeroAmount_allowed() public view {
        bytes memory claimData = _buildClaim(0);
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 0, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_noMarketPrice_allowed() public view {
        // Use a different priceFeed for which no market price is set
        AgentClaim memory claim = AgentClaim({
            priceFeed: vm.addr(0xDEAD),
            claimedPrice: 100e8,
            reasoning: "test",
            action: "SWAP",
            protocol: vm.addr(0xBB),
            expectedOutputMin: 1,
            timestamp: uint64(block.timestamp),
            expiry: uint64(block.timestamp + 1 hours)
        });
        bytes memory claimData = claim.encode();
        IPolicyEngine.PolicyOutput memory out = guard.check(claimData, agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
        assertEq(out.reason, "No market price set");
    }

    // ═══════════════════════════════════════════
    //  Admin
    // ═══════════════════════════════════════════

    function test_setConfig_onlyOwner() public {
        vm.prank(agent);
        vm.expectRevert();
        guard.setConfig(agent, 200);
    }

    function test_setConfig_revertZero() public {
        vm.expectRevert(SlippageGuard.ZeroSlippageBps.selector);
        guard.setConfig(agent, 0);
    }

    function test_setMarketPrice_onlyOwner() public {
        vm.prank(agent);
        vm.expectRevert();
        guard.setMarketPrice(priceFeed, 100e8);
    }

    function test_setMarketPrice_revertZero() public {
        vm.expectRevert(SlippageGuard.ZeroMarketPrice.selector);
        guard.setMarketPrice(priceFeed, 0);
    }

    function test_getConfig_defaultIs200() public view {
        uint16 bps = guard.getConfig(agent);
        assertEq(bps, 200);
    }

    function test_emitsEvents() public {
        vm.expectEmit(true, false, false, true);
        emit SlippageGuard.SlippageConfigSet(agent, 150);
        guard.setConfig(agent, 150);

        vm.expectEmit(true, false, false, true);
        emit SlippageGuard.MarketPriceUpdated(priceFeed, 200e8);
        guard.setMarketPrice(priceFeed, 200e8);
    }
}
