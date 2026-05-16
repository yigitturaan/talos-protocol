// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {Reputation} from "../src/types/TalosTypes.sol";
import {ContractWhitelist} from "../src/policies/ContractWhitelist.sol";
import {MockERC20Permit} from "../test/fixtures/MockERC20Permit.sol";
import {DemoPriceFeed} from "../src/demo/DemoPriceFeed.sol";
import {DemoSwapAdapter} from "../src/demo/DemoSwapAdapter.sol";
import {DemoDepositAdapter} from "../src/demo/DemoDepositAdapter.sol";

contract DeployDemo is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory jsonData = vm.readFile("../deployments/10143.json");
        address payable protocolAddr = payable(vm.parseJsonAddress(jsonData, ".TalosProtocol"));
        address whitelistAddr = vm.parseJsonAddress(jsonData, ".ContractWhitelist");

        TalosProtocol protocol = TalosProtocol(protocolAddr);
        ContractWhitelist whitelist = ContractWhitelist(whitelistAddr);

        console.log("Deployer:", deployer);
        console.log("TalosProtocol:", protocolAddr);

        vm.startBroadcast(deployerKey);

        // 1. Deploy DemoPriceFeed -- MON/USD = $0.50 (8 decimals)
        DemoPriceFeed priceFeed = new DemoPriceFeed(50_000_000, "MON / USD (demo)");
        console.log("DemoPriceFeed:", address(priceFeed));

        // 2. Deploy demo adapters
        DemoSwapAdapter swapAdapter = new DemoSwapAdapter();
        DemoDepositAdapter depositAdapter = new DemoDepositAdapter();
        console.log("DemoSwapAdapter:", address(swapAdapter));
        console.log("DemoDepositAdapter:", address(depositAdapter));

        // 3. Deploy fresh test USDC
        MockERC20Permit usdc = new MockERC20Permit("Test USDC", "tUSDC", 6);
        usdc.mint(deployer, 10_000_000e6); // 10M tUSDC
        console.log("Test USDC:", address(usdc));

        // 4. Wire demo adapters into TalosProtocol
        protocol.setSwapAdapter(address(swapAdapter));
        protocol.setDepositAdapter(address(depositAdapter));
        console.log("Adapters wired to protocol");

        // 5. Whitelist tUSDC as target contract (used as claim.protocol for demo)
        whitelist.setAllowed(address(usdc), true);
        console.log("tUSDC whitelisted");

        // 6. Check if agent is registered (skip if already done)
        Reputation memory rep = protocol.reputations(deployer);
        if (rep.registeredAt == 0) {
            protocol.registerAgent{value: 100 ether}(100 ether);
            console.log("Agent registered with 100 MON stake");
        } else {
            console.log("Agent already registered, score:", rep.score, "stake:", rep.stake);
        }

        vm.stopBroadcast();

        // Write demo addresses
        string memory out = string.concat(
            '{\n',
            '  "DemoPriceFeed": "', vm.toString(address(priceFeed)), '",\n',
            '  "DemoSwapAdapter": "', vm.toString(address(swapAdapter)), '",\n',
            '  "DemoDepositAdapter": "', vm.toString(address(depositAdapter)), '",\n',
            '  "TestUSDC": "', vm.toString(address(usdc)), '"\n',
            '}'
        );
        vm.writeFile("../deployments/demo-10143.json", out);
        console.log("---");
        console.log("Demo addresses written to deployments/demo-10143.json");
    }
}
