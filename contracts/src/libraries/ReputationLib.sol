// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Reputation} from "../types/TalosTypes.sol";

/// @notice ELO-inspired reputation scoring (Section 10 of project doc).
library ReputationLib {
    uint16 constant MAX_SCORE = 2000;
    uint16 constant INITIAL_SCORE = 1000;
    uint16 constant BAN_THRESHOLD = 100;

    uint32 constant K_NEW = 40;
    uint32 constant K_MID = 20;
    uint32 constant K_EXPERIENCED = 10;

    uint32 constant NEW_THRESHOLD = 50;
    uint32 constant MID_THRESHOLD = 200;

    enum Outcome {
        Passed,       // all layers passed: +15..+25
        HashFailed,   // layer 1 failed:   -50..-80
        OracleFailed, // layer 2 failed:   -30..-50
        PolicyFailed, // layer 3 failed:   -30..-50
        Timeout,      // escrow expired:   -10
        SoftReject    // gray zone:        -5
    }

    function getKFactor(uint32 totalVerifications) internal pure returns (uint32) {
        if (totalVerifications < NEW_THRESHOLD) return K_NEW;
        if (totalVerifications < MID_THRESHOLD) return K_MID;
        return K_EXPERIENCED;
    }

    /// @notice Apply a verification outcome to a reputation record.
    ///         Returns updated score (clamped to [0, 2000]) and updated isBanned.
    function applyResult(
        Reputation memory rep,
        Outcome outcome
    ) internal pure returns (uint16 newScore, bool banned) {
        uint32 k = getKFactor(rep.totalVerifications);
        int256 delta;

        if (outcome == Outcome.Passed) {
            delta = int256(uint256(15 * k / K_EXPERIENCED));
            if (delta > 25) delta = 25;
        } else if (outcome == Outcome.HashFailed) {
            delta = -int256(uint256(50 * k / K_MID));
            if (delta < -80) delta = -80;
        } else if (outcome == Outcome.OracleFailed || outcome == Outcome.PolicyFailed) {
            delta = -int256(uint256(30 * k / K_MID));
            if (delta < -50) delta = -50;
        } else if (outcome == Outcome.Timeout) {
            delta = -10;
        } else if (outcome == Outcome.SoftReject) {
            delta = -5;
        }

        int256 raw = int256(uint256(rep.score)) + delta;

        if (raw < 0) {
            newScore = 0;
        } else if (raw > int256(uint256(MAX_SCORE))) {
            newScore = MAX_SCORE;
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            newScore = uint16(uint256(raw));
        }

        banned = newScore < BAN_THRESHOLD;
    }
}
