// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {SpendingLimit} from "../src/policies/SpendingLimit.sol";
import {ContractWhitelist} from "../src/policies/ContractWhitelist.sol";
import {IPolicyEngine} from "../src/interfaces/IPolicyEngine.sol";
import {MockERC20Permit} from "./fixtures/MockERC20Permit.sol";

contract PolicyEnginesTest is Test {
    TalosProtocol protocol;
    SpendingLimit spendingLimit;
    ContractWhitelist contractWhitelist;
    MockERC20Permit usdc;

    address deployer = address(this);
    address agent = vm.addr(0xA1);
    address user = vm.addr(0xB1);

    address allowedContract = vm.addr(0xC1);
    address disallowedContract = vm.addr(0xC2);

    function setUp() public {
        protocol = new TalosProtocol(deployer);
        usdc = new MockERC20Permit("USD Coin", "USDC", 6);

        // Deploy policy engines — protocol is the owner so it can recordSpend
        spendingLimit = new SpendingLimit(address(protocol));
        contractWhitelist = new ContractWhitelist(deployer);

        // Register policies in protocol
        protocol.setPolicyEngine(address(spendingLimit), true);
        protocol.setPolicyEngine(address(contractWhitelist), true);

        // Setup: whitelist one contract
        contractWhitelist.setAllowed(allowedContract, true);

        // Fund and register agent
        vm.deal(agent, 200 ether);
        vm.prank(agent);
        protocol.registerAgent{value: 100 ether}(100 ether);
    }

    // ═══════════════════════════════════════════
    //  SpendingLimit — standalone check tests
    // ═══════════════════════════════════════════

    function test_spendingLimit_noLimitsConfigured_allowed() public view {
        IPolicyEngine.PolicyOutput memory out =
            spendingLimit.check("", agent, 1000e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_spendingLimit_withinDailyLimit_allowed() public {
        // SpendingLimit is owned by protocol, so we prank as protocol to set limits
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 500e6, 2000e6);

        IPolicyEngine.PolicyOutput memory out =
            spendingLimit.check("", agent, 400e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_spendingLimit_exceedsDailyLimit_denied() public {
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 500e6, 2000e6);

        // Record some prior spend
        vm.prank(address(protocol));
        spendingLimit.recordSpend(agent, 300e6);

        IPolicyEngine.PolicyOutput memory out =
            spendingLimit.check("", agent, 300e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
        assertEq(out.policy, "SpendingLimit");
        assertEq(out.reason, "Daily limit exceeded");
    }

    function test_spendingLimit_exceedsWeeklyLimit_denied() public {
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 1000e6, 2000e6);

        // Spread spend across multiple days, still within daily but exceeding weekly
        for (uint256 i; i < 5; i++) {
            vm.prank(address(protocol));
            spendingLimit.recordSpend(agent, 400e6);
            vm.warp(block.timestamp + 1 days);
        }

        // Total spent in 7 days: 2000e6. Adding 100e6 should exceed weekly limit.
        IPolicyEngine.PolicyOutput memory out =
            spendingLimit.check("", agent, 100e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
        assertEq(out.reason, "Weekly limit exceeded");
    }

    function test_spendingLimit_rollingWindow_resetsAfter24h() public {
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 500e6, 5000e6);

        // Spend 400e6 now
        vm.prank(address(protocol));
        spendingLimit.recordSpend(agent, 400e6);

        // Still in 24h window — 400 + 200 > 500
        IPolicyEngine.PolicyOutput memory denied =
            spendingLimit.check("", agent, 200e6, address(0));
        assertEq(uint8(denied.result), uint8(IPolicyEngine.PolicyResult.Denied));

        // Warp 25 hours ahead — rolling window resets
        vm.warp(block.timestamp + 25 hours);

        IPolicyEngine.PolicyOutput memory allowed =
            spendingLimit.check("", agent, 200e6, address(0));
        assertEq(uint8(allowed.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_spendingLimit_exactLimit_allowed() public {
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 500e6, 2000e6);

        IPolicyEngine.PolicyOutput memory out =
            spendingLimit.check("", agent, 500e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_spendingLimit_setLimits_onlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        spendingLimit.setLimits(agent, 500e6, 2000e6);
    }

    function test_spendingLimit_setLimits_revertZero() public {
        vm.prank(address(protocol));
        vm.expectRevert(SpendingLimit.ZeroLimit.selector);
        spendingLimit.setLimits(agent, 0, 0);
    }

    // ═══════════════════════════════════════════
    //  ContractWhitelist — standalone check tests
    // ═══════════════════════════════════════════

    function test_whitelist_allowedContract_passes() public view {
        IPolicyEngine.PolicyOutput memory out =
            contractWhitelist.check("", agent, 100e6, allowedContract);
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_whitelist_disallowedContract_denied() public view {
        IPolicyEngine.PolicyOutput memory out =
            contractWhitelist.check("", agent, 100e6, disallowedContract);
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Denied));
        assertEq(out.policy, "ContractWhitelist");
        assertEq(out.reason, "Contract not whitelisted");
    }

    function test_whitelist_zeroAddress_allowed() public view {
        IPolicyEngine.PolicyOutput memory out =
            contractWhitelist.check("", agent, 100e6, address(0));
        assertEq(uint8(out.result), uint8(IPolicyEngine.PolicyResult.Allowed));
    }

    function test_whitelist_setAllowed_onlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        contractWhitelist.setAllowed(disallowedContract, true);
    }

    function test_whitelist_updateAllowed_toggle() public {
        // Add to whitelist
        contractWhitelist.setAllowed(disallowedContract, true);
        assertTrue(contractWhitelist.isAllowed(disallowedContract));

        // Remove from whitelist
        contractWhitelist.setAllowed(disallowedContract, false);
        assertFalse(contractWhitelist.isAllowed(disallowedContract));
    }

    function test_whitelist_batchSet() public {
        address[] memory targets = new address[](3);
        targets[0] = vm.addr(0xD1);
        targets[1] = vm.addr(0xD2);
        targets[2] = vm.addr(0xD3);

        contractWhitelist.setAllowedBatch(targets, true);

        for (uint256 i; i < targets.length; i++) {
            assertTrue(contractWhitelist.isAllowed(targets[i]));
        }
    }

    function test_whitelist_batchSet_onlyOwner() public {
        address[] memory targets = new address[](1);
        targets[0] = vm.addr(0xD1);

        vm.prank(user);
        vm.expectRevert();
        contractWhitelist.setAllowedBatch(targets, true);
    }

    // ═══════════════════════════════════════════
    //  Protocol registry — setPolicyEngine
    // ═══════════════════════════════════════════

    function test_registry_policyEnginesListed() public view {
        address[] memory engines = protocol.policyEngines();
        assertEq(engines.length, 2);
        assertEq(engines[0], address(spendingLimit));
        assertEq(engines[1], address(contractWhitelist));
    }

    function test_registry_removePolicyEngine() public {
        protocol.setPolicyEngine(address(spendingLimit), false);
        address[] memory engines = protocol.policyEngines();
        assertEq(engines.length, 1);
        assertEq(engines[0], address(contractWhitelist));
    }

    function test_registry_setPolicyEngine_onlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        protocol.setPolicyEngine(vm.addr(0xF1), true);
    }

    function test_registry_noDuplicateOnDoubleAdd() public {
        protocol.setPolicyEngine(address(spendingLimit), true);
        address[] memory engines = protocol.policyEngines();
        assertEq(engines.length, 2);
    }

    // ═══════════════════════════════════════════
    //  SpendingLimit — getSpentInWindow view
    // ═══════════════════════════════════════════

    function test_spendingLimit_getSpentInWindow() public {
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 500e6, 2000e6);

        vm.prank(address(protocol));
        spendingLimit.recordSpend(agent, 100e6);

        vm.warp(block.timestamp + 12 hours);

        vm.prank(address(protocol));
        spendingLimit.recordSpend(agent, 200e6);

        uint256 daily = spendingLimit.getSpentInWindow(agent, 1 days);
        assertEq(daily, 300e6);

        uint256 weekly = spendingLimit.getSpentInWindow(agent, 7 days);
        assertEq(weekly, 300e6);
    }

    function test_spendingLimit_recordSpend_onlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        spendingLimit.recordSpend(agent, 100e6);
    }

    // ═══════════════════════════════════════════
    //  ContractWhitelist — event emission
    // ═══════════════════════════════════════════

    function test_whitelist_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ContractWhitelist.ContractAllowed(disallowedContract, true);
        contractWhitelist.setAllowed(disallowedContract, true);
    }

    function test_spendingLimit_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SpendingLimit.LimitsSet(agent, 500e6, 2000e6);
        vm.prank(address(protocol));
        spendingLimit.setLimits(agent, 500e6, 2000e6);
    }
}
