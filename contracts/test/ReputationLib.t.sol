// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Reputation} from "../src/types/TalosTypes.sol";
import {ReputationLib} from "../src/libraries/ReputationLib.sol";

contract ReputationLibTest is Test {
    using ReputationLib for Reputation;

    function _newAgent() internal pure returns (Reputation memory) {
        return Reputation({
            agent: address(0xA),
            score: 1000,
            totalVerifications: 10,
            passed: 8,
            failed: 2,
            totalVolume: 0,
            stake: 100 ether,
            registeredAt: 1,
            lastVerified: 1,
            isBanned: false
        });
    }

    function _midAgent() internal pure returns (Reputation memory) {
        Reputation memory rep = _newAgent();
        rep.totalVerifications = 100;
        return rep;
    }

    function _expAgent() internal pure returns (Reputation memory) {
        Reputation memory rep = _newAgent();
        rep.totalVerifications = 300;
        return rep;
    }

    // ═══════════════════════════════════════════
    //  K-Factor bands
    // ═══════════════════════════════════════════

    function test_kFactor_new() public pure {
        assertEq(ReputationLib.getKFactor(10), 40);
        assertEq(ReputationLib.getKFactor(0), 40);
        assertEq(ReputationLib.getKFactor(49), 40);
    }

    function test_kFactor_mid() public pure {
        assertEq(ReputationLib.getKFactor(50), 20);
        assertEq(ReputationLib.getKFactor(100), 20);
        assertEq(ReputationLib.getKFactor(199), 20);
    }

    function test_kFactor_experienced() public pure {
        assertEq(ReputationLib.getKFactor(200), 10);
        assertEq(ReputationLib.getKFactor(1000), 10);
    }

    // ═══════════════════════════════════════════
    //  Passed outcome
    // ═══════════════════════════════════════════

    function test_passed_new_agent() public pure {
        Reputation memory rep = _newAgent();
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.Passed);
        // K=40: 15*40/10 = 60 → clamped to 25
        assertEq(score, 1025);
        assertFalse(banned);
    }

    function test_passed_mid_agent() public pure {
        Reputation memory rep = _midAgent();
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.Passed);
        // K=20: 15*20/10 = 30 → clamped to 25
        assertEq(score, 1025);
        assertFalse(banned);
    }

    function test_passed_experienced_agent() public pure {
        Reputation memory rep = _expAgent();
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.Passed);
        // K=10: 15*10/10 = 15
        assertEq(score, 1015);
        assertFalse(banned);
    }

    // ═══════════════════════════════════════════
    //  HashFailed outcome
    // ═══════════════════════════════════════════

    function test_hashFailed_new_agent() public pure {
        Reputation memory rep = _newAgent();
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.HashFailed);
        // K=40: 50*40/20 = 100 → clamped to -80
        assertEq(score, 920);
        assertFalse(banned);
    }

    function test_hashFailed_mid_agent() public pure {
        Reputation memory rep = _midAgent();
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.HashFailed);
        // K=20: 50*20/20 = 50
        assertEq(score, 950);
        assertFalse(banned);
    }

    function test_hashFailed_experienced_agent() public pure {
        Reputation memory rep = _expAgent();
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.HashFailed);
        // K=10: 50*10/20 = 25
        assertEq(score, 975);
        assertFalse(banned);
    }

    // ═══════════════════════════════════════════
    //  OracleFailed outcome
    // ═══════════════════════════════════════════

    function test_oracleFailed_new_agent() public pure {
        Reputation memory rep = _newAgent();
        (uint16 score,) = rep.applyResult(ReputationLib.Outcome.OracleFailed);
        // K=40: 30*40/20 = 60 → clamped to -50
        assertEq(score, 950);
    }

    function test_oracleFailed_experienced_agent() public pure {
        Reputation memory rep = _expAgent();
        (uint16 score,) = rep.applyResult(ReputationLib.Outcome.OracleFailed);
        // K=10: 30*10/20 = 15
        assertEq(score, 985);
    }

    // ═══════════════════════════════════════════
    //  Timeout and SoftReject
    // ═══════════════════════════════════════════

    function test_timeout() public pure {
        Reputation memory rep = _newAgent();
        (uint16 score,) = rep.applyResult(ReputationLib.Outcome.Timeout);
        assertEq(score, 990);
    }

    function test_softReject() public pure {
        Reputation memory rep = _newAgent();
        (uint16 score,) = rep.applyResult(ReputationLib.Outcome.SoftReject);
        assertEq(score, 995);
    }

    // ═══════════════════════════════════════════
    //  Clamp and Ban
    // ═══════════════════════════════════════════

    function test_clamp_to_zero() public pure {
        Reputation memory rep = _newAgent();
        rep.score = 30;
        (uint16 score, bool banned) = rep.applyResult(ReputationLib.Outcome.HashFailed);
        // 30 - 80 = -50 → clamped to 0
        assertEq(score, 0);
        assertTrue(banned);
    }

    function test_clamp_to_max() public pure {
        Reputation memory rep = _expAgent();
        rep.score = 1995;
        (uint16 score,) = rep.applyResult(ReputationLib.Outcome.Passed);
        // 1995 + 15 = 2010 → clamped to 2000
        assertEq(score, 2000);
    }

    function test_ban_threshold_boundary() public pure {
        Reputation memory rep = _newAgent();
        rep.score = 100;
        // score exactly at threshold — NOT banned yet
        (uint16 score1, bool banned1) = rep.applyResult(ReputationLib.Outcome.SoftReject);
        assertEq(score1, 95);
        assertTrue(banned1); // 95 < 100 → banned

        // score just above
        rep.score = 106;
        (uint16 score2, bool banned2) = rep.applyResult(ReputationLib.Outcome.SoftReject);
        assertEq(score2, 101);
        assertFalse(banned2); // 101 >= 100 → not banned
    }

    function test_policyFailed_same_as_oracle() public pure {
        Reputation memory rep = _newAgent();
        (uint16 s1,) = rep.applyResult(ReputationLib.Outcome.OracleFailed);
        (uint16 s2,) = rep.applyResult(ReputationLib.Outcome.PolicyFailed);
        assertEq(s1, s2);
    }
}
