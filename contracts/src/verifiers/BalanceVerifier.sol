// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {AgentClaim} from "../types/TalosTypes.sol";
import {ClaimEncoder} from "../libraries/ClaimEncoder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice On-chain balance verification — exact match, zero tolerance.
///         references[0] = token, references[1] = account.
///         claimData decoded as AgentClaim: claimedPrice → claimedBalance,
///         expectedOutputMin → minimum required for the transaction.
///         Balance lies are bad intent → always HardReject on mismatch.
contract BalanceVerifier is IVerifier {
    using ClaimEncoder for bytes;

    function verify(
        bytes calldata claimData,
        address[] calldata references
    ) external view override returns (VerificationOutput memory) {
        address token = references[0];
        address account = references[1];

        AgentClaim memory claim = ClaimEncoder.decode(claimData);
        uint256 claimedBalance = claim.claimedPrice;
        uint256 txAmount = claim.expectedOutputMin;

        // Validate token is ERC20: staticcall balanceOf, check return size
        (bool success, bytes memory returnData) = token.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, account)
        );

        if (!success || returnData.length < 32) {
            return VerificationOutput({
                result: VerificationResult.HardReject,
                deviationBps: 10000,
                reason: "Token is not a valid ERC20"
            });
        }

        uint256 actualBalance = abi.decode(returnData, (uint256));

        // Exact match — tolerance 0. Balance lie = bad intent.
        if (actualBalance != claimedBalance) {
            uint256 diff = actualBalance > claimedBalance
                ? actualBalance - claimedBalance
                : claimedBalance - actualBalance;

            uint256 rawDeviation;
            if (actualBalance > 0) {
                rawDeviation = (diff * 10000) / actualBalance;
                if (rawDeviation > 10000) rawDeviation = 10000;
            } else {
                rawDeviation = 10000;
            }

            return VerificationOutput({
                result: VerificationResult.HardReject,
                // safe: rawDeviation is capped at 10000 which fits uint16
                deviationBps: uint16(rawDeviation),
                reason: "Balance mismatch"
            });
        }

        // Balance must cover the transaction amount
        if (txAmount > 0 && actualBalance < txAmount) {
            return VerificationOutput({
                result: VerificationResult.HardReject,
                deviationBps: 10000,
                reason: "Insufficient balance for transaction"
            });
        }

        return VerificationOutput({
            result: VerificationResult.Passed,
            deviationBps: 0,
            reason: ""
        });
    }
}
