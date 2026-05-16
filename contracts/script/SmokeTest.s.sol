// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TalosProtocol} from "../src/TalosProtocol.sol";
import {MockERC20Permit} from "../test/fixtures/MockERC20Permit.sol";
import {Escrow, EscrowStatus, AgentClaim} from "../src/types/TalosTypes.sol";
import {ClaimEncoder} from "../src/libraries/ClaimEncoder.sol";

contract SmokeTest is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory jsonData = vm.readFile("../deployments/10143.json");
        address payable protocolAddr = payable(vm.parseJsonAddress(jsonData, ".TalosProtocol"));
        TalosProtocol protocol = TalosProtocol(protocolAddr);

        console.log("Deployer:", deployer);
        console.log("TalosProtocol:", protocolAddr);

        vm.startBroadcast(deployerKey);

        // 1. Deploy test USDC
        MockERC20Permit usdc = new MockERC20Permit("Test USDC", "tUSDC", 6);
        usdc.mint(deployer, 1_000_000e6);
        console.log("Test USDC:", address(usdc));
        console.log("Minted 1M tUSDC to deployer");

        // 2. lockEscrow
        bytes16 intentId = bytes16(uint128(1));
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 3600);

        usdc.approve(protocolAddr, amount);
        protocol.lockEscrow(intentId, deployer, address(usdc), amount, expiry);
        console.log("lockEscrow OK - intentId: 1, amount: 100 tUSDC");

        // 3. commit
        AgentClaim memory claim = AgentClaim({
            priceFeed: address(0),
            claimedPrice: 1_000_000,
            reasoning: "smoke test",
            action: "TEST",
            protocol: address(0),
            expectedOutputMin: 1,
            timestamp: uint64(block.timestamp),
            expiry: uint64(block.timestamp + 300)
        });
        bytes32 claimHash = ClaimEncoder.hash(claim);
        protocol.commit(intentId, claimHash);
        console.log("commit OK - claimHash written");

        vm.stopBroadcast();

        // 4. Verify state
        Escrow memory esc = protocol.escrows(intentId);
        require(esc.status == EscrowStatus.Committed, "Expected Committed status");
        require(esc.owner == deployer, "Wrong owner");
        require(esc.agent == deployer, "Wrong agent");
        require(esc.amount == amount, "Wrong amount");
        console.log("---");
        console.log("SMOKE TEST PASSED");
        console.log("  Escrow status: Committed");
        console.log("  Owner/Agent:", deployer);
        console.log("  Amount: 100 tUSDC");
    }
}
