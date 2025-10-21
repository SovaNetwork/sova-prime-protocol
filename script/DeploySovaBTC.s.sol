// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {SovaBTC} from "../src/token/SovaBtc.sol";

/**
 * @title DeploySovaBTCScript
 * @notice Script to deploy the SovaBTC token
 * @dev Deploys SovaBTC with configurable owner, mint manager, and burn manager
 */
contract DeploySovaBTCScript is Script {
    SovaBTC public sovaBTC;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get role managers from environment or use deployer as default
        address owner = vm.envOr("OWNER", deployer);
        address mintManager = vm.envOr("MINT_MANAGER", deployer);
        address burnManager = vm.envOr("BURN_MANAGER", deployer);

        console.log("=== Deploying SovaBTC ===");
        console.log("Deployer:", deployer);
        console.log("Owner:", owner);
        console.log("Mint Manager:", mintManager);
        console.log("Burn Manager:", burnManager);

        vm.startBroadcast(deployerPrivateKey);

        sovaBTC = new SovaBTC(owner, mintManager, burnManager);

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("SovaBTC deployed at:", address(sovaBTC));
        console.log("  Name:", sovaBTC.name());
        console.log("  Symbol:", sovaBTC.symbol());
        console.log("  Decimals:", sovaBTC.decimals());
        console.log("  Owner:", owner);
        console.log("  Mint Manager:", mintManager);
        console.log("  Burn Manager:", burnManager);
    }
}
