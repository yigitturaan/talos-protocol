// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {StateVerifier} from "../src/verifiers/StateVerifier.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fork tests against real Monad mainnet contracts.
///         Run: forge test --match-contract StateVerifierTest --fork-url https://rpc.monad.xyz -vvv
contract StateVerifierTest is Test {
    StateVerifier verifier;

    address constant WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address constant POOL_MANAGER = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;

    bytes4 constant SEL_TOTAL_SUPPLY = IERC20.totalSupply.selector;
    bytes4 constant SEL_BALANCE_OF = IERC20.balanceOf.selector;
    bytes4 constant SEL_DECIMALS = bytes4(keccak256("decimals()"));

    function setUp() public {
        verifier = new StateVerifier();
    }

    // ═══════════════════════════════════════════
    //  Helpers
    // ═══════════════════════════════════════════

    function _encode(
        bytes4 sel,
        bytes memory callArgs,
        uint256 claimedValue,
        uint16 toleranceBps
    ) internal pure returns (bytes memory) {
        return abi.encode(sel, callArgs, claimedValue, toleranceBps);
    }

    function _refs(address target) internal pure returns (address[] memory) {
        address[] memory r = new address[](1);
        r[0] = target;
        return r;
    }

    // ═══════════════════════════════════════════
    //  totalSupply: exact match -> Passed
    // ═══════════════════════════════════════════

    function test_totalSupply_exact_passed() public {
        uint256 realSupply = IERC20(WMON).totalSupply();
        console2.log("WMON totalSupply:", realSupply);
        assertTrue(realSupply > 0);

        bytes memory claimData = _encode(SEL_TOTAL_SUPPLY, "", realSupply, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  totalSupply: within tolerance -> Passed
    // ═══════════════════════════════════════════

    function test_totalSupply_withinTolerance_passed() public {
        uint256 realSupply = IERC20(WMON).totalSupply();

        // Claim 0.5% higher, tolerance 100 bps (1%)
        uint256 claimedValue = realSupply * 10050 / 10000;
        bytes memory claimData = _encode(SEL_TOTAL_SUPPLY, "", claimedValue, 100);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertGt(out.deviationBps, 0);
        assertLe(out.deviationBps, 100);
    }

    // ═══════════════════════════════════════════
    //  totalSupply: exceeds tolerance -> HardReject
    // ═══════════════════════════════════════════

    function test_totalSupply_exceedsTolerance_hardReject() public {
        uint256 realSupply = IERC20(WMON).totalSupply();

        // Claim 10% higher, tolerance 100 bps (1%)
        uint256 claimedValue = realSupply * 110 / 100;
        bytes memory claimData = _encode(SEL_TOTAL_SUPPLY, "", claimedValue, 100);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertGt(out.deviationBps, 100);
    }

    // ═══════════════════════════════════════════
    //  balanceOf(address): exact match -> Passed
    // ═══════════════════════════════════════════

    function test_balanceOf_withArgs_exact_passed() public {
        uint256 realBalance = IERC20(WMON).balanceOf(POOL_MANAGER);
        console2.log("PoolManager WMON balance:", realBalance);
        assertTrue(realBalance > 0);

        bytes memory callArgs = abi.encode(POOL_MANAGER);
        bytes memory claimData = _encode(SEL_BALANCE_OF, callArgs, realBalance, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  decimals(): uint8 return decoded as uint256 -> Passed
    // ═══════════════════════════════════════════

    function test_decimals_passed() public {
        bytes memory claimData = _encode(SEL_DECIMALS, "", 18, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  Invalid target (EOA, no code) -> HardReject
    // ═══════════════════════════════════════════

    function test_invalidTarget_hardReject() public {
        address eoa = address(0xdead0001);

        bytes memory claimData = _encode(SEL_TOTAL_SUPPLY, "", 1 ether, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(eoa)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertEq(out.deviationBps, 10000);
    }

    // ═══════════════════════════════════════════
    //  Zero tolerance, off by one -> HardReject
    // ═══════════════════════════════════════════

    function test_zeroTolerance_offByOne_hardReject() public {
        // decimals() returns 18 — claiming 19 is a 555 bps deviation
        bytes memory claimData = _encode(SEL_DECIMALS, "", 19, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
        assertGt(out.deviationBps, 0);
    }

    // ═══════════════════════════════════════════
    //  Non-existent selector -> HardReject
    // ═══════════════════════════════════════════

    function test_badSelector_hardReject() public {
        bytes4 fakeSel = bytes4(keccak256("nonExistentFunction()"));

        bytes memory claimData = _encode(fakeSel, "", 0, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(WMON)
        );

        // WMON likely reverts on unknown selector
        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.HardReject));
    }

    // ═══════════════════════════════════════════
    //  Real Multicall3 getBlockNumber -> Passed
    // ═══════════════════════════════════════════

    function test_multicall3_blockNumber_passed() public {
        address multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
        bytes4 sel = bytes4(keccak256("getBlockNumber()"));

        uint256 currentBlock = block.number;
        bytes memory claimData = _encode(sel, "", currentBlock, 0);
        IVerifier.VerificationOutput memory out = verifier.verify(
            claimData, _refs(multicall3)
        );

        assertEq(uint8(out.result), uint8(IVerifier.VerificationResult.Passed));
        assertEq(out.deviationBps, 0);
    }
}
