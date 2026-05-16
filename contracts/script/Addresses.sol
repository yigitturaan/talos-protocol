// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Canonical addresses for Monad mainnet (chain 143).
///         Verified 2026-05-15 from:
///         - Chainlink: reference-data-directory.vercel.app/feeds-monad-mainnet.json
///         - Uniswap: developers.uniswap.org/contracts/v4/deployments
///         - Monad: docs.monad.xyz
///         Used in fork tests and deploy scripts. Single source of truth alongside addresses.json.
library Addresses {
    // ═══════════════════════════════════════════════════════
    // Monad Native
    // ═══════════════════════════════════════════════════════
    address constant WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    // ═══════════════════════════════════════════════════════
    // ERC-20 Tokens — Monad Mainnet
    // ═══════════════════════════════════════════════════════
    // Source: dexscreener.com/monad, verified via cast call on mainnet
    address constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;

    // ═══════════════════════════════════════════════════════
    // Uniswap V4 — Monad Mainnet (chain 143)
    // ═══════════════════════════════════════════════════════
    address constant UNI_V4_POOL_MANAGER = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;
    address constant UNI_V4_UNIVERSAL_ROUTER = 0x0D97Dc33264bfC1c226207428A79b26757fb9dc3;
    address constant UNI_V4_POSITION_MANAGER = 0x5b7eC4a94fF9beDb700fb82aB09d5846972F4016;
    address constant UNI_V4_STATE_VIEW = 0x77395F3b2E73aE90843717371294fa97cC419D64;
    address constant UNI_V4_QUOTER = 0xa222Dd357A9076d1091Ed6Aa2e16C9742dD26891;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // ═══════════════════════════════════════════════════════
    // Chainlink Price Feeds — Monad Mainnet
    // Source: reference-data-directory.vercel.app/feeds-monad-mainnet.json
    // ═══════════════════════════════════════════════════════

    // MON/USD — 18 decimals, heartbeat 3600s, deviation 0.05%
    address constant CHAINLINK_MON_USD = 0xFB504aD06Ab5E6c63FE0A46FEa245214838E8015;
    // MON/USD SVR — 18 decimals, deviation 0.02% (MEV recapture oracle)
    address constant CHAINLINK_MON_USD_SVR = 0x432AAcD32253B6683f6483fB0d3285bA0082EfDb;
    // BTC/USD — 8 decimals, heartbeat 3600s
    address constant CHAINLINK_BTC_USD = 0xc1d4C3331635184fA4C3c22fb92211B2Ac9E0546;
    // ETH/USD — 8 decimals, heartbeat 3600s
    address constant CHAINLINK_ETH_USD = 0x1B1414782B859871781bA3E4B0979b9ca57A0A04;
    // USDC/USD — 8 decimals, heartbeat 3600s
    address constant CHAINLINK_USDC_USD = 0xf5F15f188AbCB0d165D1Edb7f37F7d6fA2fCebec;
    // USDT/USD — 8 decimals, heartbeat 3600s
    address constant CHAINLINK_USDT_USD = 0x1a1Be4c184923a6BFF8c27cfDf6ac8bDE4DE00FC;
    // SOL/USD — 8 decimals, heartbeat 3600s
    address constant CHAINLINK_SOL_USD = 0x16F8008c3e89f62e5e2b909Ce70999370D38F4F2;
    // LINK/USD — 8 decimals, heartbeat 3600s
    address constant CHAINLINK_LINK_USD = 0x5c266b5c655664d6c99a13fF0d7F1F7eaF4Ac9ba;

    // ═══════════════════════════════════════════════════════
    // ERC-20 Tokens — Monad Mainnet (continued)
    // ═══════════════════════════════════════════════════════
    // Source: on-chain verified via eth_call name()/decimals()
    address constant WETH = 0xEE8c0E9f1BFFb4Eb878d8f15f368A02a35481242;

    // ═══════════════════════════════════════════════════════
    // Morpho Vaults — Monad Mainnet (ERC-4626)
    // Source: app.morpho.org/monad/earn — verified on-chain 2026-05-16
    // ═══════════════════════════════════════════════════════
    address constant MORPHO_STEAKHOUSE_ETH = 0xbeef04b01e0275D4ac2e2986256BB14E3Ff6ef42;
    address constant MORPHO_STEAKHOUSE_USDC = 0xbeEFf443C3CbA3E369DA795002243BeaC311aB83;
}
