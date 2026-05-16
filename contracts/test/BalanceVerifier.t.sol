// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {BalanceVerifier} from "../src/verifiers/BalanceVerifier.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {AgentClaim} from "../src/types/TalosTypes.sol";
import {ClaimEncoder} from "../src/libraries/ClaimEncoder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fork tests against real Monad mainnet ERC-20 tokens.
///         Run: forge test --match-contract BalanceVerifierTest --fork-url https://rpc.monad.xyz -vvv
contract BalanceVerifierTest is Test {
    using ClaimEncoder for AgentClaim;

    BalanceVerifier verifier;

    // Real Monad mainnet addresses
    address constant WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address constant POOL_MANAGER = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;

    function setUp() public {
        verifier = new BalanceVerifier();
    }

    // ═══════════════════════════════════════════
    //  Helper: build balance claim
    // ═══════════════════════════════════════════

    function _buildBalanceClaim(
        uint256 claimedBalance,
        uint256 txAmount
    ) internal view returns (bytes memory) {
        AgentClaim memory claim = AgentClaim({
            priceFeed: WMON,
            claimedPrice: claimedBalance,
            reasoning: "balance check",
            action: "swap",
            protocol: address(0xdead),
            expectedOutputMin: txAmount,
            timestamp: uint64(block.timestamp),
            expiry: uint64(block.timestamp + 3600)
        });
        return ClaimEncoder.encode(claim);
    }

    function _refs(address token, address account) internal pure returns (address[] memory) {
        address[] memory r = new address[](2);
        r[0] = token;
        r[1] = account;
        return r;
    }

    // ═══════════════════════════════════════════
    //  Real WMON: exact balance → Passed
    // ═══════════════════════════════════════════

    function test_exactBalance_passed() public {
        uint256 realBalance = IERC20(WMON).balanceOf(POOL_MANAGER);
        console2.log("PoolManager WMON balance:", realBalance);
        assertTrue(realBalance > 0, "PoolManager has no WMON - fork data issue");

        bytes memory claimData = _buildBalanceClaim(realBalance, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, POOL_MANAGER)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  Real WMON: overclaimed balance → HardReject
    // ═══════════════════════════════════════════

    function test_overclaimed_hardReject() public {
        uint256 realBalance = IERC20(WMON).balanceOf(POOL_MANAGER);
        uint256 fakeBalance = realBalance + 1000 ether;

        bytes memory claimData = _buildBalanceClaim(fakeBalance, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, POOL_MANAGER)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertGt(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  Real WMON: underclaimed balance → HardReject
    // ═══════════════════════════════════════════

    function test_underclaimed_hardReject() public {
        uint256 realBalance = IERC20(WMON).balanceOf(POOL_MANAGER);
        uint256 fakeBalance = realBalance / 2;

        bytes memory claimData = _buildBalanceClaim(fakeBalance, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, POOL_MANAGER)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertEq(out.deviationBps, 5000); // 50% underclaim
    }

    // ═══════════════════════════════════════════
    //  Not an ERC20 → HardReject
    // ═══════════════════════════════════════════

    function test_notERC20_hardReject() public {
        address notErc20 = address(0x1);

        bytes memory claimData = _buildBalanceClaim(1 ether, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(notErc20, POOL_MANAGER)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertEq(out.deviationBps, 10000);
    }

    // ═══════════════════════════════════════════
    //  Insufficient balance for tx → HardReject
    // ═══════════════════════════════════════════

    function test_insufficientBalance_hardReject() public {
        uint256 realBalance = IERC20(WMON).balanceOf(POOL_MANAGER);

        // Claim exact balance but txAmount exceeds it
        uint256 txAmount = realBalance + 1;
        bytes memory claimData = _buildBalanceClaim(realBalance, txAmount);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, POOL_MANAGER)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertEq(out.deviationBps, 10000);
    }

    // ═══════════════════════════════════════════
    //  Exact balance + txAmount within balance → Passed
    // ═══════════════════════════════════════════

    function test_balanceSufficient_passed() public {
        uint256 realBalance = IERC20(WMON).balanceOf(POOL_MANAGER);

        // Claim exact balance, txAmount is within
        uint256 txAmount = realBalance / 2;
        bytes memory claimData = _buildBalanceClaim(realBalance, txAmount);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, POOL_MANAGER)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  Zero balance account: claim 0 → Passed
    // ═══════════════════════════════════════════

    function test_zeroBalance_correctClaim_passed() public {
        address nobody = address(0xdead0000dead0000dead);
        uint256 bal = IERC20(WMON).balanceOf(nobody);
        assertEq(bal, 0, "Expected zero WMON balance for random address");

        bytes memory claimData = _buildBalanceClaim(0, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, nobody)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  Zero balance account: claim non-zero → HardReject
    // ═══════════════════════════════════════════

    function test_zeroBalance_fakeClaim_hardReject() public {
        address nobody = address(0xdead0000dead0000dead);

        bytes memory claimData = _buildBalanceClaim(100 ether, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, nobody)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertEq(out.deviationBps, 10000); // actual=0, deviation max
    }

    // ═══════════════════════════════════════════
    //  Prank'd real transfer: exact match → Passed
    // ═══════════════════════════════════════════

    function test_prankTransfer_exactMatch_passed() public {
        address recipient = address(0xBEEF);
        uint256 transferAmount = 1 ether;

        uint256 pmBalance = IERC20(WMON).balanceOf(POOL_MANAGER);
        assertTrue(pmBalance >= transferAmount, "PoolManager needs >= 1 WMON");

        // prank'li gercek transfer
        vm.prank(POOL_MANAGER);
        IERC20(WMON).transfer(recipient, transferAmount);

        uint256 recipientBal = IERC20(WMON).balanceOf(recipient);
        assertEq(recipientBal, transferAmount);

        bytes memory claimData = _buildBalanceClaim(transferAmount, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData,
            _refs(WMON, recipient)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }
}
