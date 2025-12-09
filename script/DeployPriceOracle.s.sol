// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";

/**
 * @title DeployPriceOracleScript
 * @notice Deploys a new PriceOracleReporter with correct 18-decimal price
 */
contract DeployPriceOracleScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get updater address from environment or use deployer as default
        address updater = vm.envOr("UPDATER_ADDRESS", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // CRITICAL: Price must be in 18 decimals (1e18 = 1.0)
        // For 1:1 peg with any asset (BTC, USDC, etc.)
        uint256 initialPrice = 1 * 10**18; // 1.0 in 18-decimal precision

        PriceOracleReporter priceOracle = new PriceOracleReporter(
            initialPrice,
            updater,
            100,    // 1% max change
            3600    // per hour
        );

        console.log("PriceOracleReporter deployed:");
        console.log("  Address:", address(priceOracle));
        console.log("  Initial Price:", initialPrice);
        console.log("  Updater:", updater);

        vm.stopBroadcast();
    }
}
