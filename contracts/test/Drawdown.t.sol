// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Drawdown} from "../src/policies/Drawdown.sol";
import {IPolicyEngine} from "../src/interfaces/IPolicyEngine.sol";

contract DrawdownTest is Test {

    Drawdown drawdown;

    address deployer = address(this);
    address agent = vm.addr(0xA1);

    function setUp() public {
        drawdown = new Drawdown(deployer);
    }

    // ═══════════════════════════════════════════
    //  No config — passthrough
    // ═══════════════════════════════════════════

    function test_noConfig_allowed() public view {
        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
        assertEq(out.reason, "No config set");
    }

    // ═══════════════════════════════════════════
    //  Drawdown not triggered
    // ═══════════════════════════════════════════

    function test_withinDrawdownLimit_allowed() public {
        // initial=10_000e6, maxDrawdown=20% → threshold=8_000e6
        drawdown.setConfig(agent, 10_000e6, 20);

        // Portfolio at 9_000e6 → above threshold
        drawdown.updatePortfolioValue(agent, 9_000e6);

        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 500e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_exactThreshold_allowed() public {
        // initial=10_000e6, maxDrawdown=20% → threshold=8_000e6
        drawdown.setConfig(agent, 10_000e6, 20);

        // Portfolio exactly at threshold → allowed (not below)
        drawdown.updatePortfolioValue(agent, 8_000e6);

        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 500e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    // ═══════════════════════════════════════════
    //  Drawdown triggered
    // ═══════════════════════════════════════════

    function test_drawdownExceeded_denied() public {
        // initial=10_000e6, maxDrawdown=20% → threshold=8_000e6
        drawdown.setConfig(agent, 10_000e6, 20);

        // Portfolio at 7_999e6 → below threshold → DENIED
        drawdown.updatePortfolioValue(agent, 7_999e6);

        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 500e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
        assertEq(out.policy, "Drawdown");
        assertEq(out.reason, "Max drawdown exceeded");
    }

    function test_drawdownSevere_denied() public {
        drawdown.setConfig(agent, 10_000e6, 20);

        // Portfolio at 5_000e6 → 50% drop, way beyond 20% limit
        drawdown.updatePortfolioValue(agent, 5_000e6);

        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 100e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
    }

    function test_portfolioRecovery_allowed() public {
        drawdown.setConfig(agent, 10_000e6, 20);

        // Drop below threshold
        drawdown.updatePortfolioValue(agent, 7_000e6);
        IPolicyEngine.PolicyOutput memory denied = drawdown.check("", agent, 100e6, address(0));
        assertEq(uint8(denied.result), uint8(IPolicyEngine.PolicyResult.Denied));

        // Recover above threshold
        drawdown.updatePortfolioValue(agent, 8_500e6);
        IPolicyEngine.PolicyOutput memory allowed = drawdown.check("", agent, 100e6, address(0));
        assertEq(uint8(allowed.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    // ═══════════════════════════════════════════
    //  Different drawdown percentages
    // ═══════════════════════════════════════════

    function test_tightDrawdown5pct() public {
        // initial=10_000e6, maxDrawdown=5% → threshold=9_500e6
        drawdown.setConfig(agent, 10_000e6, 5);

        drawdown.updatePortfolioValue(agent, 9_499e6);
        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 100e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));

        drawdown.updatePortfolioValue(agent, 9_500e6);
        IPolicyEngine.PolicyOutput memory allowed = drawdown.check("", agent, 100e6, address(0));
        assertEq(uint8(allowed.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    // ═══════════════════════════════════════════
    //  Initial state (just configured, no updatePortfolioValue)
    // ═══════════════════════════════════════════

    function test_initialState_allowed() public {
        // After setConfig, currentValue==initialValue → no drawdown
        drawdown.setConfig(agent, 10_000e6, 20);

        IPolicyEngine.PolicyOutput memory out = drawdown.check("", agent, 500e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    // ═══════════════════════════════════════════
    //  Admin / Access control
    // ═══════════════════════════════════════════

    function test_setConfig_onlyOwner() public {
        vm.prank(agent);
        vm.expectRevert();
        drawdown.setConfig(agent, 10_000e6, 20);
    }

    function test_setConfig_revertZeroInitialValue() public {
        vm.expectRevert(Drawdown.ZeroInitialValue.selector);
        drawdown.setConfig(agent, 0, 20);
    }

    function test_setConfig_revertZeroDrawdownPct() public {
        vm.expectRevert(Drawdown.ZeroDrawdownPct.selector);
        drawdown.setConfig(agent, 10_000e6, 0);
    }

    function test_setConfig_revertDrawdownPctTooHigh() public {
        vm.expectRevert(Drawdown.DrawdownPctTooHigh.selector);
        drawdown.setConfig(agent, 10_000e6, 101);
    }

    function test_updatePortfolioValue_onlyOwner() public {
        drawdown.setConfig(agent, 10_000e6, 20);
        vm.prank(agent);
        vm.expectRevert();
        drawdown.updatePortfolioValue(agent, 5_000e6);
    }

    function test_getConfig() public {
        drawdown.setConfig(agent, 10_000e6, 20);
        drawdown.updatePortfolioValue(agent, 9_000e6);
        (uint256 init, uint256 current, uint8 pct) = drawdown.getConfig(agent);
        assertEq(init, 10_000e6);
        assertEq(current, 9_000e6);
        assertEq(pct, 20);
    }

    function test_emitsEvents() public {
        vm.expectEmit(true, false, false, true);
        emit Drawdown.DrawdownConfigSet(agent, 10_000e6, 20);
        drawdown.setConfig(agent, 10_000e6, 20);

        vm.expectEmit(true, false, false, true);
        emit Drawdown.PortfolioValueUpdated(agent, 8_000e6);
        drawdown.updatePortfolioValue(agent, 8_000e6);
    }
}
