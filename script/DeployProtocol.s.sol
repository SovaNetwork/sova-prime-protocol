// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {KycRulesHook} from "../src/hooks/KycRulesHook.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {GatedMintReportedStrategy} from "../src/strategy/GatedMintRWAStrategy.sol";
import {ManagedWithdrawReportedStrategy} from "../src/strategy/ManagedWithdrawRWAStrategy.sol";
import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Conduit} from "../src/conduit/Conduit.sol";

contract DeployProtocolScript is Script {
    // Management addresses
    address public constant MANAGER_1 = 0xdf49B0293131eb1386B9BBE0dE894C0aB7439f06;
    address public constant MANAGER_2 = 0xe578129e06FCFa3E24E4A1C36e31600211f9d75E;

    // Storage for deployed contract addresses
    RoleManager public roleManager;
    MockERC20 public mockBtcToken;
    Registry public registry;
    KycRulesHook public kycRulesHook;
    PriceOracleReporter public priceOracle;
    ReportedStrategy public reportedStrategyImplementation;
    // GatedMintReportedStrategy public gatedMintStrategyImplementation;
    // ManagedWithdrawReportedStrategy public managedWithdrawStrategyImplementation;
    BtcVaultStrategy public btcVaultStrategyImplementation;
    Conduit public conduit;

    function setUp() public {}

    function run() public {
        // Use the private key directly from the command line parameter
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core infrastructure
        deployInfrastructure(deployer);

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
        mockBtcToken = new MockERC20("Mock BTC", "WBTC", 8);

        // Mint tokens to various addresses for testing
        mockBtcToken.mint(deployer, 50_000_000_000); // 500 BTC
        mockBtcToken.mint(MANAGER_1, 50_000_000_000); // 500 BTC
        mockBtcToken.mint(MANAGER_2, 50_000_000_000); // 500 BTC

        console.log("Mock USD Token deployed and minted to managers.");

        // Deploy Registry with role manager
        registry = new Registry(address(roleManager));
        console.log("Registry deployed.");

        conduit = Conduit(registry.conduit());

        // Link registry to role manager
        roleManager.initializeRegistry(address(registry));

        // Allow USD token as an asset
        registry.setAsset(address(mockBtcToken), 6);

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
        uint256 initialPrice = 100_000_000; // 1 BTC with 8 decimals
        priceOracle = new PriceOracleReporter(initialPrice, MANAGER_1, 500, 3600); // 5% max change per hour
        priceOracle.setUpdater(MANAGER_2, true);
        console.log("Price Oracle Reporter deployed.");

        // Deploy ReportedStrategy implementation to be used as a template
        reportedStrategyImplementation = new ReportedStrategy();
        console.log("ReportedStrategy implementation deployed.");

        // // Deploy GatedMintReportedStrategy implementation to be used as a template
        // gatedMintStrategyImplementation = new GatedMintReportedStrategy();
        // console.log("GatedMintReportedStrategy implementation deployed.");

        // // Deploy ManagedWithdrawReportedStrategy implementation to be used as a template
        // managedWithdrawStrategyImplementation = new ManagedWithdrawReportedStrategy();
        // console.log("ManagedWithdrawReportedStrategy implementation deployed.");

        // Deploy ManagedWithdrawReportedStrategy implementation to be used as a template
        btcVaultStrategyImplementation = new BtcVaultStrategy();
        console.log("BtcVaultStrategyImplementation implementation deployed.");

        // Register both strategy implementations in the registry
        registry.setStrategy(address(reportedStrategyImplementation), true);
        // registry.setStrategy(address(gatedMintStrategyImplementation), true);
        registry.setStrategy(address(btcVaultStrategyImplementation), true);
        console.log("Registry configured with strategy implementations.");
    }

    function grantRolesToManagers() internal {
        // Grant KYC_OPERATOR to deployer for deployment
        roleManager.grantRole(roleManager.owner(), roleManager.KYC_OPERATOR());

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

    function logDeployedContracts() internal view {
        // Log deployed contract addresses
        console.log("\nDeployed contracts:");
        console.log("Role Manager:", address(roleManager));
        console.log("Mock BTC Token:", address(mockBtcToken));
        console.log("Registry:", address(registry));
        console.log("Conduit:", address(conduit));
        console.log("KYC Rules Hook:", address(kycRulesHook));
        console.log("Price Oracle Reporter:", address(priceOracle));
        console.log("ReportedStrategy Implementation:", address(reportedStrategyImplementation));
        // console.log("GatedMintReportedStrategy Implementation:", address(gatedMintStrategyImplementation));
        console.log("ManagedWithdrawReportedStrategy Implementation:", address(btcVaultStrategyImplementation));
    }
}
