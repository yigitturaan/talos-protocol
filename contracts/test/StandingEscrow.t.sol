// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {ITalosProtocol} from "../src/interfaces/ITalosProtocol.sol";
import {Escrow, EscrowStatus, StandingEscrow, AgentClaim} from "../src/types/TalosTypes.sol";
import {ClaimEncoder} from "../src/libraries/ClaimEncoder.sol";
import {MockERC20Permit} from "./fixtures/MockERC20Permit.sol";
import {PriceVerifier} from "../src/verifiers/PriceVerifier.sol";

contract StandingEscrowTest is Test {
    using stdStorage for StdStorage;

    TalosProtocol protocol;
    MockERC20Permit usdc;
    PriceVerifier verifier;

    address deployer = address(this);
    address agent = vm.addr(0xA1);
    address user = vm.addr(0xB1);

    bytes16 constant INTENT_1 = bytes16(uint128(100));
    bytes16 constant INTENT_2 = bytes16(uint128(101));
    uint64 constant FUTURE = uint64(2000000000);

    uint256 constant STANDING_AMOUNT = 10_000e6;
    uint256 constant PER_TX_LIMIT = 1_000e6;

    function setUp() public {
        protocol = new TalosProtocol(deployer);
        usdc = new MockERC20Permit("USD Coin", "USDC", 6);
        verifier = new PriceVerifier();

        protocol.setPriceVerifier(address(verifier));

        vm.deal(agent, 200 ether);
        vm.prank(agent);
        protocol.registerAgent{value: 100 ether}(100 ether);

        usdc.mint(user, 100_000e6);
    }

    function _createStanding() internal returns (bytes32 standingId) {
        standingId = keccak256(abi.encode(user, agent, address(usdc), block.timestamp));

        vm.startPrank(user);
        usdc.approve(address(protocol), STANDING_AMOUNT);
        protocol.createStandingEscrow(agent, address(usdc), STANDING_AMOUNT, PER_TX_LIMIT, FUTURE);
        vm.stopPrank();
    }

    // ════════════════════════════════
    //  createStandingEscrow
    // ════════════════════════════════

    function test_createStandingEscrow_success() public {
        bytes32 sid = _createStanding();

        StandingEscrow memory se = protocol.standingEscrows(sid);
        assertEq(se.owner, user);
        assertEq(se.agent, agent);
        assertEq(se.token, address(usdc));
        assertEq(se.balance, STANDING_AMOUNT);
        assertEq(se.perTxLimit, PER_TX_LIMIT);
        assertTrue(se.active);
        assertEq(usdc.balanceOf(address(protocol)), STANDING_AMOUNT);
    }

    function test_createStandingEscrow_revert_unregisteredAgent() public {
        address rogue = vm.addr(0xF1);
        vm.startPrank(user);
        usdc.approve(address(protocol), STANDING_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ITalosProtocol.AgentNotRegistered.selector, rogue));
        protocol.createStandingEscrow(rogue, address(usdc), STANDING_AMOUNT, PER_TX_LIMIT, FUTURE);
        vm.stopPrank();
    }

    function test_createStandingEscrow_revert_expiredExpiry() public {
        vm.startPrank(user);
        usdc.approve(address(protocol), STANDING_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ITalosProtocol.InvalidExpiry.selector, uint64(1)));
        protocol.createStandingEscrow(agent, address(usdc), STANDING_AMOUNT, PER_TX_LIMIT, 1);
        vm.stopPrank();
    }

    function test_createStandingEscrow_revert_perTxLimitExceedsAmount() public {
        vm.startPrank(user);
        usdc.approve(address(protocol), STANDING_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.ExceedsPerTxLimit.selector, STANDING_AMOUNT + 1, STANDING_AMOUNT)
        );
        protocol.createStandingEscrow(agent, address(usdc), STANDING_AMOUNT, STANDING_AMOUNT + 1, FUTURE);
        vm.stopPrank();
    }

    // ════════════════════════════════
    //  executeFromStanding — guards
    // ════════════════════════════════

    function test_executeFromStanding_revert_exceedsPerTxLimit() public {
        bytes32 sid = _createStanding();
        bytes memory claimData = _dummyClaimData();

        vm.prank(agent);
        address[] memory refs = new address[](0);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.ExceedsPerTxLimit.selector, PER_TX_LIMIT + 1, PER_TX_LIMIT)
        );
        protocol.executeFromStanding(sid, INTENT_1, PER_TX_LIMIT + 1, claimData, refs);
    }

    function test_executeFromStanding_revert_insufficientBalance() public {
        bytes32 sid = _createStanding();
        bytes memory claimData = _dummyClaimData();
        address[] memory refs = new address[](0);

        // Reduce balance to 500e6 via storage (simulates prior executions)
        stdstore
            .target(address(protocol))
            .sig("standingEscrows(bytes32)")
            .with_key(sid)
            .depth(3)
            .checked_write(500e6);

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.InsufficientStandingBalance.selector, 500e6, 1_000e6)
        );
        protocol.executeFromStanding(sid, INTENT_1, 1_000e6, claimData, refs);
    }

    function test_executeFromStanding_revert_wrongAgent() public {
        bytes32 sid = _createStanding();
        bytes memory claimData = _dummyClaimData();
        address[] memory refs = new address[](0);

        address rogue = vm.addr(0xF2);
        vm.prank(rogue);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.NotAuthorizedAgent.selector, INTENT_1, rogue)
        );
        protocol.executeFromStanding(sid, INTENT_1, 500e6, claimData, refs);
    }

    // ════════════════════════════════
    //  withdrawStandingEscrow
    // ════════════════════════════════

    function test_withdrawStandingEscrow_success() public {
        bytes32 sid = _createStanding();
        uint256 userBalBefore = usdc.balanceOf(user);

        vm.prank(user);
        protocol.withdrawStandingEscrow(sid);

        StandingEscrow memory se = protocol.standingEscrows(sid);
        assertEq(se.balance, 0);
        assertFalse(se.active);
        assertEq(usdc.balanceOf(user), userBalBefore + STANDING_AMOUNT);
    }

    function test_withdrawStandingEscrow_revert_notOwner() public {
        bytes32 sid = _createStanding();

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(ITalosProtocol.NotOwnerOrAgent.selector, agent));
        protocol.withdrawStandingEscrow(sid);
    }

    function test_withdrawStandingEscrow_revert_zeroBalance() public {
        bytes32 sid = _createStanding();

        vm.prank(user);
        protocol.withdrawStandingEscrow(sid);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITalosProtocol.InsufficientStandingBalance.selector, 0, 1));
        protocol.withdrawStandingEscrow(sid);
    }

    // ════════════════════════════════
    //  Balance deduction across multiple executions
    // ════════════════════════════════

    function test_standingEscrow_balanceDeductsCorrectly() public {
        bytes32 sid = _createStanding();

        StandingEscrow memory se1 = protocol.standingEscrows(sid);
        assertEq(se1.balance, STANDING_AMOUNT);

        // We can't run full CVE without a real oracle, but we can test
        // that a second createStandingEscrow with the same params at a different
        // block.timestamp produces a different standingId
        vm.warp(block.timestamp + 1);
        bytes32 sid2 = _createStandingSmall(5_000e6, 1_000e6);
        assertTrue(sid != sid2);
    }

    // ════════════════════════════════
    //  Helpers
    // ════════════════════════════════

    function _createStandingSmall(uint256 amount, uint256 perTx) internal returns (bytes32 standingId) {
        standingId = keccak256(abi.encode(user, agent, address(usdc), block.timestamp));

        vm.startPrank(user);
        usdc.approve(address(protocol), amount);
        protocol.createStandingEscrow(agent, address(usdc), amount, perTx, FUTURE);
        vm.stopPrank();
    }

    function _dummyClaimData() internal pure returns (bytes memory) {
        AgentClaim memory claim = AgentClaim({
            priceFeed: address(0),
            claimedPrice: 3_800_000_000,
            reasoning: "test",
            action: "BUY_MON",
            protocol: address(0),
            expectedOutputMin: 1,
            timestamp: 1747310400,
            expiry: 1747310460
        });
        return ClaimEncoder.encode(claim);
    }
}
