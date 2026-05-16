// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC4626 {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function totalAssets() external view returns (uint256);
}

/// @notice Adapter for depositing into ERC-4626 vaults (Morpho, etc.) on Monad.
contract MorphoAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error VaultAssetMismatch(address expected, address actual);
    error InsufficientShares(uint256 received, uint256 minRequired);

    event DepositExecuted(
        address indexed vault,
        address indexed depositor,
        uint256 assets,
        uint256 shares,
        address receiver
    );

    /// @notice Deposit assets into an ERC-4626 vault. Shares go to receiver.
    /// @param vault The ERC-4626 vault address.
    /// @param token The asset token to deposit.
    /// @param amount Amount of asset tokens to deposit.
    /// @param minShares Minimum shares to receive (slippage protection).
    /// @param receiver Address that receives the vault shares.
    function deposit(
        address vault,
        address token,
        uint256 amount,
        uint256 minShares,
        address receiver
    ) external nonReentrant returns (uint256 shares) {
        if (vault == address(0) || token == address(0) || receiver == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) revert ZeroAmount();

        address vaultAsset = IERC4626(vault).asset();
        if (vaultAsset != token) {
            revert VaultAssetMismatch(vaultAsset, token);
        }

        IERC20(token).safeIncreaseAllowance(vault, amount);

        shares = IERC4626(vault).deposit(amount, receiver);

        if (shares < minShares) {
            revert InsufficientShares(shares, minShares);
        }

        emit DepositExecuted(vault, msg.sender, amount, shares, receiver);
    }
}
