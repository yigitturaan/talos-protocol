// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Addresses} from "./Addresses.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {ContractWhitelist} from "../src/policies/ContractWhitelist.sol";

contract ConfigureProtocol is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory deployPath = string.concat("../deployments/", vm.toString(block.chainid), ".json");
        string memory jsonData = vm.readFile(deployPath);

        address protocolAddr = vm.parseJsonAddress(jsonData, ".TalosProtocol");
        address whitelistAddr = vm.parseJsonAddress(jsonData, ".ContractWhitelist");

        console.log("Deployer:", deployer);
        console.log("TalosProtocol:", protocolAddr);
        console.log("ContractWhitelist:", whitelistAddr);
        console.log("Chain ID:", block.chainid);
        console.log("---");

        ContractWhitelist whitelist = ContractWhitelist(whitelistAddr);

        vm.startBroadcast(deployerKey);

        // 1. Whitelist Uniswap V4 Universal Router (swap target)
        whitelist.setAllowed(Addresses.UNI_V4_UNIVERSAL_ROUTER, true);
        console.log("Whitelisted UniversalRouter:", Addresses.UNI_V4_UNIVERSAL_ROUTER);

        // 2. Whitelist Morpho vaults (deposit targets)
        whitelist.setAllowed(Addresses.MORPHO_STEAKHOUSE_ETH, true);
        console.log("Whitelisted Morpho Steakhouse ETH:", Addresses.MORPHO_STEAKHOUSE_ETH);

        whitelist.setAllowed(Addresses.MORPHO_STEAKHOUSE_USDC, true);
        console.log("Whitelisted Morpho Steakhouse USDC:", Addresses.MORPHO_STEAKHOUSE_USDC);

        // 3. Whitelist Permit2 (used by UniswapV4Adapter)
        whitelist.setAllowed(Addresses.PERMIT2, true);
        console.log("Whitelisted Permit2:", Addresses.PERMIT2);

        vm.stopBroadcast();

        console.log("---");
        console.log("Configuration complete.");
        console.log("Chainlink feeds are referenced at verify-time via AgentClaim.priceFeed - no on-chain mapping needed.");
        console.log("Policy ceilings are set per-escrow at lockEscrow time via PolicyConfig struct.");
    }
}
