// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Addresses} from "./Addresses.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {PriceVerifier} from "../src/verifiers/PriceVerifier.sol";
import {BalanceVerifier} from "../src/verifiers/BalanceVerifier.sol";
import {StateVerifier} from "../src/verifiers/StateVerifier.sol";
import {SpendingLimit} from "../src/policies/SpendingLimit.sol";
import {ContractWhitelist} from "../src/policies/ContractWhitelist.sol";
import {SlippageGuard} from "../src/policies/SlippageGuard.sol";
import {Drawdown} from "../src/policies/Drawdown.sol";
import {UniswapV4Adapter} from "../src/execution/UniswapV4Adapter.sol";
import {MorphoAdapter} from "../src/execution/MorphoAdapter.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("---");

        vm.startBroadcast(deployerKey);

        // 1. Verifiers
        PriceVerifier priceVerifier = new PriceVerifier();
        console.log("PriceVerifier:", address(priceVerifier));

        BalanceVerifier balanceVerifier = new BalanceVerifier();
        console.log("BalanceVerifier:", address(balanceVerifier));

        StateVerifier stateVerifier = new StateVerifier();
        console.log("StateVerifier:", address(stateVerifier));

        // 2. Policy engines (owner = deployer)
        SpendingLimit spendingLimit = new SpendingLimit(deployer);
        console.log("SpendingLimit:", address(spendingLimit));

        ContractWhitelist whitelist = new ContractWhitelist(deployer);
        console.log("ContractWhitelist:", address(whitelist));

        SlippageGuard slippageGuard = new SlippageGuard(deployer);
        console.log("SlippageGuard:", address(slippageGuard));

        Drawdown drawdown = new Drawdown(deployer);
        console.log("Drawdown:", address(drawdown));

        // 3. Execution adapters (use Addresses.sol — mainnet addrs for fork; testnet has no Uniswap/Morpho)
        UniswapV4Adapter swapAdapter = new UniswapV4Adapter(
            Addresses.UNI_V4_UNIVERSAL_ROUTER,
            Addresses.PERMIT2,
            Addresses.UNI_V4_POOL_MANAGER
        );
        console.log("UniswapV4Adapter:", address(swapAdapter));

        MorphoAdapter morphoAdapter = new MorphoAdapter();
        console.log("MorphoAdapter:", address(morphoAdapter));

        // 4. Core protocol
        TalosProtocol protocol = new TalosProtocol(deployer);
        console.log("TalosProtocol:", address(protocol));

        // 5. Wire verifier + adapters
        protocol.setPriceVerifier(address(priceVerifier));
        protocol.setSwapAdapter(address(swapAdapter));
        protocol.setDepositAdapter(address(morphoAdapter));

        // 6. Register policy engines
        protocol.setPolicyEngine(address(spendingLimit), true);
        protocol.setPolicyEngine(address(whitelist), true);
        protocol.setPolicyEngine(address(slippageGuard), true);
        protocol.setPolicyEngine(address(drawdown), true);

        vm.stopBroadcast();

        console.log("---");
        console.log("Deploy complete. Wire ConfigureProtocol next.");

        _writeDeploymentJson(
            address(protocol),
            address(priceVerifier),
            address(balanceVerifier),
            address(stateVerifier),
            address(swapAdapter),
            address(morphoAdapter),
            address(spendingLimit),
            address(whitelist),
            address(slippageGuard),
            address(drawdown)
        );
    }

    function _writeDeploymentJson(
        address protocol,
        address priceVerifier,
        address balanceVerifier,
        address stateVerifier,
        address swapAdapter,
        address morphoAdapter,
        address spendingLimit,
        address whitelist,
        address slippageGuard,
        address drawdown
    ) internal {
        string memory json = string.concat(
            '{\n',
            '  "_chainId": ', vm.toString(block.chainid), ',\n',
            '  "TalosProtocol": "', vm.toString(protocol), '",\n',
            '  "PriceVerifier": "', vm.toString(priceVerifier), '",\n',
            '  "BalanceVerifier": "', vm.toString(balanceVerifier), '",\n',
            '  "StateVerifier": "', vm.toString(stateVerifier), '",\n',
            '  "UniswapV4Adapter": "', vm.toString(swapAdapter), '",\n',
            '  "MorphoAdapter": "', vm.toString(morphoAdapter), '",\n',
            '  "SpendingLimit": "', vm.toString(spendingLimit), '",\n',
            '  "ContractWhitelist": "', vm.toString(whitelist), '",\n',
            '  "SlippageGuard": "', vm.toString(slippageGuard), '",\n',
            '  "Drawdown": "', vm.toString(drawdown), '"\n',
            '}\n'
        );

        string memory path = string.concat("../deployments/", vm.toString(block.chainid), ".json");
        vm.writeFile(path, json);
        console.log("Wrote deployment JSON:", path);
    }
}
