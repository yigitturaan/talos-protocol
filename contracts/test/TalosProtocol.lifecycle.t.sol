// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {ITalosProtocol} from "../src/interfaces/ITalosProtocol.sol";
import {Escrow, EscrowStatus, Reputation} from "../src/types/TalosTypes.sol";
import {MockERC20Permit} from "./fixtures/MockERC20Permit.sol";

contract TalosProtocolLifecycleTest is Test {
    TalosProtocol protocol;
    MockERC20Permit usdc;

    address deployer = address(this);
    address agent = vm.addr(0xA1);
    address user = vm.addr(0xB1);
    uint256 userPk = 0xB1;
    address bannedAgent = vm.addr(0xC1);

    bytes16 constant INTENT_1 = bytes16(uint128(1));
    bytes16 constant INTENT_2 = bytes16(uint128(2));
    uint64 constant FUTURE = uint64(2000000000);

    function setUp() public {
        protocol = new TalosProtocol(deployer);
        usdc = new MockERC20Permit("USD Coin", "USDC", 6);

        // Fund and register agent
        vm.deal(agent, 200 ether);
        vm.prank(agent);
        protocol.registerAgent{value: 100 ether}(100 ether);

        // Register and ban an agent for testing
        vm.deal(bannedAgent, 200 ether);
        vm.prank(bannedAgent);
        protocol.registerAgent{value: 100 ether}(100 ether);

        // Mint USDC to user
        usdc.mint(user, 100_000e6);
    }

    // ═══════════════════════════════════════════
    //  registerAgent
    // ═══════════════════════════════════════════

    function test_registerAgent_success() public view {
        Reputation memory rep = protocol.reputations(agent);
        assertEq(rep.score, 1000);
        assertEq(rep.stake, 100 ether);
        assertTrue(rep.registeredAt > 0);
        assertFalse(rep.isBanned);
    }

    function test_registerAgent_revert_insufficientStake() public {
        address newAgent = vm.addr(0xD1);
        vm.deal(newAgent, 200 ether);
        vm.prank(newAgent);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.InsufficientStake.selector, 50 ether, 100 ether)
        );
        protocol.registerAgent{value: 50 ether}(50 ether);
    }

    function test_registerAgent_revert_insufficientMsgValue() public {
        address newAgent = vm.addr(0xD2);
        vm.deal(newAgent, 200 ether);
        vm.prank(newAgent);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.InsufficientStake.selector, 50 ether, 100 ether)
        );
        protocol.registerAgent{value: 50 ether}(100 ether);
    }

    function test_registerAgent_revert_alreadyRegistered() public {
        vm.deal(agent, 200 ether);
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.AgentAlreadyRegistered.selector, agent)
        );
        protocol.registerAgent{value: 100 ether}(100 ether);
    }

    function test_registerAgent_emitsEvent() public {
        address newAgent = vm.addr(0xD3);
        vm.deal(newAgent, 200 ether);
        vm.prank(newAgent);
        vm.expectEmit(true, false, false, true);
        emit ITalosProtocol.AgentRegistered(newAgent, 150 ether);
        protocol.registerAgent{value: 150 ether}(150 ether);
    }

    // ═══════════════════════════════════════════
    //  lockEscrow
    // ═══════════════════════════════════════════

    function test_lockEscrow_success() public {
        vm.startPrank(user);
        usdc.approve(address(protocol), 1000e6);
        protocol.lockEscrow(INTENT_1, agent, address(usdc), 1000e6, FUTURE);
        vm.stopPrank();

        Escrow memory esc = protocol.escrows(INTENT_1);
        assertEq(esc.owner, user);
        assertEq(esc.agent, agent);
        assertEq(esc.token, address(usdc));
        assertEq(esc.amount, 1000e6);
        assertTrue(esc.status == EscrowStatus.Locked);
        assertEq(esc.commitHash, bytes32(0));
        assertFalse(esc.verified);

        assertEq(usdc.balanceOf(address(protocol)), 1000e6);
        assertEq(usdc.balanceOf(user), 99_000e6);
    }

    function test_lockEscrow_revert_agentNotRegistered() public {
        address unknown = vm.addr(0xE1);
        vm.startPrank(user);
        usdc.approve(address(protocol), 1000e6);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.AgentNotRegistered.selector, unknown)
        );
        protocol.lockEscrow(INTENT_1, unknown, address(usdc), 1000e6, FUTURE);
        vm.stopPrank();
    }

    function test_lockEscrow_revert_duplicateIntent() public {
        vm.startPrank(user);
        usdc.approve(address(protocol), 2000e6);
        protocol.lockEscrow(INTENT_1, agent, address(usdc), 1000e6, FUTURE);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.IntentAlreadyExists.selector, INTENT_1)
        );
        protocol.lockEscrow(INTENT_1, agent, address(usdc), 1000e6, FUTURE);
        vm.stopPrank();
    }

    function test_lockEscrow_revert_invalidExpiry() public {
        vm.startPrank(user);
        usdc.approve(address(protocol), 1000e6);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.InvalidExpiry.selector, uint64(0))
        );
        protocol.lockEscrow(INTENT_1, agent, address(usdc), 1000e6, uint64(0));
        vm.stopPrank();
    }

    function test_lockEscrow_emitsEvent() public {
        vm.startPrank(user);
        usdc.approve(address(protocol), 1000e6);
        vm.expectEmit(true, true, true, true);
        emit ITalosProtocol.EscrowLocked(INTENT_1, user, agent, address(usdc), 1000e6);
        protocol.lockEscrow(INTENT_1, agent, address(usdc), 1000e6, FUTURE);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════
    //  lockEscrowWithPermit
    // ═══════════════════════════════════════════

    function test_lockEscrowWithPermit_success() public {
        uint256 amount = 1000e6;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                usdc.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(protocol),
                        amount,
                        usdc.nonces(user),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, permitHash);

        vm.prank(user);
        protocol.lockEscrowWithPermit(
            INTENT_1, agent, address(usdc), amount, FUTURE, deadline, v, r, s
        );

        Escrow memory esc = protocol.escrows(INTENT_1);
        assertEq(esc.owner, user);
        assertEq(esc.amount, amount);
        assertTrue(esc.status == EscrowStatus.Locked);
        assertEq(usdc.balanceOf(address(protocol)), amount);
    }

    // ═══════════════════════════════════════════
    //  commit
    // ═══════════════════════════════════════════

    function test_commit_success() public {
        _lockEscrow(INTENT_1);

        bytes32 claimHash = keccak256("test_claim");
        vm.prank(agent);
        protocol.commit(INTENT_1, claimHash);

        Escrow memory esc = protocol.escrows(INTENT_1);
        assertTrue(esc.status == EscrowStatus.Committed);
        assertEq(esc.commitHash, claimHash);
    }

    function test_commit_revert_notAuthorized() public {
        _lockEscrow(INTENT_1);

        address imposter = vm.addr(0xF1);
        vm.prank(imposter);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.NotAuthorizedAgent.selector, INTENT_1, imposter)
        );
        protocol.commit(INTENT_1, keccak256("bad"));
    }

    function test_commit_revert_wrongState() public {
        _lockEscrow(INTENT_1);

        vm.prank(agent);
        protocol.commit(INTENT_1, keccak256("first"));

        // Try to commit again — status is Committed, not Locked
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITalosProtocol.InvalidEscrowStatus.selector,
                INTENT_1,
                EscrowStatus.Committed,
                EscrowStatus.Locked
            )
        );
        protocol.commit(INTENT_1, keccak256("second"));
    }

    function test_commit_revert_expired() public {
        uint64 nearExpiry = uint64(block.timestamp + 10);
        vm.startPrank(user);
        usdc.approve(address(protocol), 1000e6);
        protocol.lockEscrow(INTENT_1, agent, address(usdc), 1000e6, nearExpiry);
        vm.stopPrank();

        vm.warp(nearExpiry);
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(ITalosProtocol.EscrowExpired.selector, INTENT_1)
        );
        protocol.commit(INTENT_1, keccak256("late"));
    }

    function test_commit_emitsEvent() public {
        _lockEscrow(INTENT_1);
        bytes32 claimHash = keccak256("test_claim");

        vm.prank(agent);
        vm.expectEmit(true, true, false, true);
        emit ITalosProtocol.ClaimCommitted(INTENT_1, agent, claimHash);
        protocol.commit(INTENT_1, claimHash);
    }

    // ═══════════════════════════════════════════
    //  Full lifecycle: lock → commit
    // ═══════════════════════════════════════════

    function test_fullLifecycle_lockThenCommit() public {
        _lockEscrow(INTENT_1);

        Escrow memory esc1 = protocol.escrows(INTENT_1);
        assertTrue(esc1.status == EscrowStatus.Locked);

        bytes32 claimHash = keccak256("real_claim");
        vm.prank(agent);
        protocol.commit(INTENT_1, claimHash);

        Escrow memory esc2 = protocol.escrows(INTENT_1);
        assertTrue(esc2.status == EscrowStatus.Committed);
        assertEq(esc2.commitHash, claimHash);
    }

    // ═══════════════════════════════════════════
    //  Helper
    // ═══════════════════════════════════════════

    function _lockEscrow(bytes16 intentId) internal {
        vm.startPrank(user);
        usdc.approve(address(protocol), 1000e6);
        protocol.lockEscrow(intentId, agent, address(usdc), 1000e6, FUTURE);
        vm.stopPrank();
    }
}
