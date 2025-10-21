// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";

/**
 * @title DeployBtcVaultStrategyScript
 * @notice Script to deploy BtcVaultStrategy
 * @dev Deploys the strategy implementation and clone. Requires SovaBTC to be already deployed.
 */
contract DeployBtcVaultStrategyScript is Script {
    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    Registry public registry;
    PriceOracleReporter public priceOracle;
    address public sovaBTC = 0xA06c38E864cdF486dC650858101224B1e5aA1a90;

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT RESULTS
    //////////////////////////////////////////////////////////////*/

    address public strategyImplementation;
    address public strategy;
    address public vaultToken;

    function setUp() public {
        // Load configuration from environment variables
        address registryAddress = vm.envOr("REGISTRY_ADDRESS", address(0x046C73420dE4c1A0D134c70800Cd9D62C9A70Dea));
        address priceOracleAddress =
            vm.envOr("PRICE_ORACLE_ADDRESS", address(0xDe01983a12bc440aCE843c6FFd2B7a5A7Bb38c0d));

        registry = Registry(registryAddress);
        priceOracle = PriceOracleReporter(priceOracleAddress);

        // Check if implementation address is provided
        strategyImplementation = vm.envOr("BTC_VAULT_IMPL", address(0));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy or use existing strategy implementation
        deployStrategyImplementation();

        // Step 2: Deploy strategy clone through registry
        deployStrategyClone(deployer);

        // Step 3: Log summary
        logDeploymentSummary();

        vm.stopBroadcast();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deployStrategyImplementation() internal {
        if (strategyImplementation != address(0)) {
            console.log("Using existing BtcVaultStrategy implementation at:", strategyImplementation);
            return;
        }

        console.log("=== Deploying BtcVaultStrategy Implementation ===");

        BtcVaultStrategy impl = new BtcVaultStrategy();
        strategyImplementation = address(impl);

        // Register in registry
        registry.setStrategy(strategyImplementation, true);

        console.log("Implementation deployed at:", strategyImplementation);
        console.log("Registered in registry");
    }

    function deployStrategyClone(address deployer) internal {
        console.log("\n=== Deploying BtcVaultStrategy Clone ===");

        // Get configuration
        string memory tokenName = vm.envOr("TOKEN_NAME", string("Sova Prime SOVA"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("spSOVA"));
        uint8 assetDecimals = 8;

        // Register asset if needed
        if (registry.allowedAssets(sovaBTC) == 0) {
            console.log("Registering sovaBTC as allowed asset (8 decimals)");
            registry.setAsset(sovaBTC, assetDecimals);
        } else {
            console.log("SovaBTC already registered as allowed asset");
        }

        // Prepare initialization data
        bytes memory initData = abi.encode(address(priceOracle));

        console.log("Deploying with parameters:");
        console.log("  Vault Name:", tokenName);
        console.log("  Vault Symbol:", tokenSymbol);
        console.log("  Asset (sovaBTC):", sovaBTC);
        console.log("  Manager:", deployer);
        console.log("  Price Oracle:", address(priceOracle));

        // Deploy through registry
        (strategy, vaultToken) =
            registry.deploy(strategyImplementation, tokenName, tokenSymbol, sovaBTC, deployer, initData);

        console.log("Strategy deployed at:", strategy);
        console.log("Vault token deployed at:", vaultToken);
    }

    function logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("SovaBTC Token:           ", sovaBTC);
        console.log("Strategy Implementation: ", strategyImplementation);
        console.log("Strategy Clone:          ", strategy);
        console.log("Vault Token:             ", vaultToken);
    }
}
