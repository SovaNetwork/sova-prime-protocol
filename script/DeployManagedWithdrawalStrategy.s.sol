// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ManagedWithdrawReportedStrategy} from "../src/strategy/ManagedWithdrawRWAStrategy.sol";

/**
 * @title DeployManagedWithdrawalStrategyScript
 * @notice Script to deploy a ManagedWithdrawReportedStrategy
 * @dev This script either deploys a new implementation or uses an existing one
 *      and then deploys a clone of that implementation.
 */
contract DeployManagedWithdrawalStrategyScript is Script {
    // Deployed contracts from previous scripts
    Registry public registry;
    MockERC20 public usdToken;
    PriceOracleReporter public priceOracle;

    // Implementation and clone addresses
    address public strategyImplementation;
    address public strategy;
    address public token;

    function setUp() public {
        // Parse addresses from environment variables or use defaults
        address registryAddress = vm.envOr("REGISTRY_ADDRESS", address(0x7184439dE8801d7914bd9C3DA73403AA4C9CD484));
        // address usdTokenAddress = vm.envOr("TOKEN_ADDRESS", address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)); // WBTC on eth mainnet
        address usdTokenAddress = vm.envOr("TOKEN_ADDRESS", address(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf)); // cbBTC on base mainnet
        address priceOracleAddress =
            vm.envOr("PRICE_ORACLE_ADDRESS", address(0xc9500d6a369e1d0fec48F8423c21585668882610));

        // Initialize contract references
        registry = Registry(registryAddress);
        usdToken = MockERC20(usdTokenAddress);
        priceOracle = PriceOracleReporter(priceOracleAddress);

        // Check if implementation address is provided
        strategyImplementation = vm.envOr("MANAGED_WITHDRAW_IMPL", address(0xe36cA831DF7DDD2b8955718f5f66BbB8cA5F343D));
    }

    function run() public {
        // Use the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation if not provided
        if (strategyImplementation == address(0)) {
            console.log("Deploying new ManagedWithdrawReportedStrategy implementation");
            ManagedWithdrawReportedStrategy newImpl = new ManagedWithdrawReportedStrategy();
            strategyImplementation = address(newImpl);

            // Register the implementation in the registry
            registry.setStrategy(strategyImplementation, true);
            console.log("Registered implementation in registry");
        } else {
            console.log("Using existing implementation at:", strategyImplementation);
        }

        // Deploy strategy clone
        deployStrategy(deployer);

        // Log deployed strategy details
        logDeployedStrategy();

        vm.stopBroadcast();
    }

    function deployStrategy(address deployer) internal {
        // Get token parameters from environment or use defaults
        string memory tokenName = vm.envOr("TOKEN_NAME", string("Sova Prime Bitcoin"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("spBTC"));

        // Get asset decimals from environment or use default for WBTC (8 decimals)
        uint8 assetDecimals = uint8(vm.envOr("ASSET_DECIMALS", uint256(8)));

        // Check if asset is registered, if not, register it
        if (registry.allowedAssets(address(usdToken)) == 0) {
            console.log("Asset not registered. Registering asset with", assetDecimals, "decimals");
            registry.setAsset(address(usdToken), assetDecimals);
            console.log("Asset registered successfully");
        } else {
            console.log("Asset already registered");
        }

        // Encode initialization data for the strategy (reporter address)
        bytes memory initData = abi.encode(address(priceOracle));

        console.log("Deploying strategy with parameters:");
        console.log("  Token Name:", tokenName);
        console.log("  Token Symbol:", tokenSymbol);
        console.log("  Asset:", address(usdToken));
        console.log("  Manager:", deployer);

        // Deploy strategy through registry
        (strategy, token) =
            registry.deploy(strategyImplementation, tokenName, tokenSymbol, address(usdToken), deployer, initData);

        console.log("Strategy successfully deployed");
    }

    function logDeployedStrategy() internal view {
        // Log deployed contract addresses
        console.log("\nDeployed Strategy:");
        console.log("Strategy Implementation:", strategyImplementation);
        console.log("Cloned Strategy:", strategy);
        console.log("Strategy Token:", token);
    }
}
