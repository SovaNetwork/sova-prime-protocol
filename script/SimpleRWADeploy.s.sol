// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {KycRulesHook} from "../src/hooks/KycRulesHook.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {BasicStrategy} from "../src/strategy/BasicStrategy.sol";
import {tRWA} from "../src/token/tRWA.sol";

contract SimpleRWADeployScript is Script {
    // Management addresses
    address public constant MANAGER_1 = 0x0670faf0016E1bf591fEd8e0322689E894104F81;
    address public constant MANAGER_2 = 0xc67DD6f32147285A9e4D92774055cE3Dba5Ae8b6;

    // Storage for deployed contract addresses
    RoleManager public roleManager;
    MockERC20 public usdToken;
    Registry public registry;
    KycRulesHook public kycRulesHook;
    PriceOracleReporter public priceOracle;
    ReportedStrategy public strategyImplementation;
    address public strategy;
    address public token;
    uint256 public startTime;
    uint256 public endTime;

    function setUp() public {}

    function run() public {
        // Use the private key directly from the command line parameter
        uint256 deployerPrivateKey = 0x267aedad5dceb451cc0a93b451dd21726b4a23bb83d946c9d0e0e2587069684a;
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core infrastructure
        deployInfrastructure(deployer);

        // Deploy strategy and controller
        deployStrategy(deployer);

        // Log all deployed contracts
        logDeployedContracts();

        vm.stopBroadcast();
    }

    function deployInfrastructure(address deployer) internal {
        // Deploy Role Manager first for better access control
        roleManager = new RoleManager();

        // Grant admin roles to manager addresses
        grantRolesToManagers();

        console.log("RoleManager deployed and roles configured.");

        // Deploy mock USD token
        usdToken = new MockERC20("Mock USD", "USDC", 6);

        // Mint tokens to various addresses for testing
        usdToken.mint(deployer, 1_000_000_000); // 1,000 USDC with 6 decimals
        usdToken.mint(MANAGER_1, 1_000_000_000); // 1,000 USDC with 6 decimals
        usdToken.mint(MANAGER_2, 1_000_000_000); // 1,000 USDC with 6 decimals

        console.log("Mock USD Token deployed and minted to managers.");

        // Deploy Registry with role manager
        registry = new Registry(address(roleManager));
        console.log("Registry deployed.");

        // Link registry to role manager
        roleManager.initializeRegistry(address(registry));

        // Allow USD token as an asset
        registry.setAsset(address(usdToken), 6);

        // Deploy KYC Rules Hook with role manager
        kycRulesHook = new KycRulesHook(address(roleManager));
        console.log("KYC Rules Hook deployed.");

        // Add this hook to allowed hooks in registry
        registry.setHook(address(kycRulesHook), true);

        // Allow addresses in KYC rules
        kycRulesHook.allow(deployer);
        kycRulesHook.allow(MANAGER_1);
        kycRulesHook.allow(MANAGER_2);
        console.log("Managers allowed in KYC rules.");

        // Deploy Price Oracle Reporter with initial price of 1 USD
        // CRITICAL: Price must be in 18 decimals (1e18 = 1.0)
        uint256 initialPrice = 1 * 10**18; // $1.00 in 18-decimal precision
        priceOracle = new PriceOracleReporter(initialPrice, address(roleManager), 100, 300); // 1% max change per 5 minutes
        console.log("Price Oracle Reporter deployed.");

        // Deploy ReportedStrategy implementation to be used as a template
        strategyImplementation = new ReportedStrategy();
        console.log("ReportedStrategy implementation deployed.");

        // Register the strategy implementation in the registry
        registry.setStrategy(address(strategyImplementation), true);
        console.log("Registry configured.");
    }

    function grantRolesToManagers() internal {
        // Protocol admins
        roleManager.grantRole(MANAGER_1, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.PROTOCOL_ADMIN());

        // Strategy roles
        roleManager.grantRole(MANAGER_1, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.STRATEGY_OPERATOR());
        roleManager.grantRole(MANAGER_2, roleManager.STRATEGY_OPERATOR());

        // KYC roles
        roleManager.grantRole(MANAGER_1, roleManager.RULES_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.RULES_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.KYC_OPERATOR());
        roleManager.grantRole(MANAGER_2, roleManager.KYC_OPERATOR());
    }

    function deployStrategy(address deployer) internal {
        // Encode initialization data for the strategy (reporter address)
        bytes memory initData = abi.encode(address(priceOracle));

        // Deploy strategy through registry
        (strategy, token) = registry.deploy(
            address(strategyImplementation),
            "Fountfi USD Token", // name
            "fUSDC", // symbol
            address(usdToken),
            deployer, // Manager of the strategy
            initData
        );
    }

    function logDeployedContracts() internal view {
        // Log deployed contract addresses
        console.log("\nDeployed contracts:");
        console.log("Role Manager:", address(roleManager));
        console.log("Mock USD Token:", address(usdToken));
        console.log("Registry:", address(registry));
        console.log("KYC Rules Hook:", address(kycRulesHook));
        console.log("Price Oracle Reporter:", address(priceOracle));
        console.log("Strategy Implementation:", address(strategyImplementation));
        console.log("Cloned Strategy:", strategy);
        console.log("Strategy Token:", token);
    }
}
