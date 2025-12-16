// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {BasicStrategy} from "../src/strategy/BasicStrategy.sol";

contract TransferToMultisigScript is Script {
    // Deployed contract addresses (Base mainnet)
    address constant ROLE_MANAGER = 0xf97fC42e1B3c4c570cD0Ebc9f0967fF7C49B4360;
    address constant CLONED_STRATEGY = 0xc23AE9352739E0AC242Bf0263980769C06a8F52B; // The actual deployed strategy clone

    // Target multisig
    address constant MULTISIG = 0x10A88eeF2dbf31598AAF58a4BD810cBC73E8b802;

    // Old role holders to revoke
    address constant OLD_OWNER = 0x76F2DAD4741CB0f4C8C56361d8cF5E05Bc01Bf28; // Current RoleManager owner
    address constant OLD_MANAGER_1 = 0x7b1ddf2eaa19bae051bdCf9cf446cB98E8Dc13Df;
    address constant OLD_MANAGER_2 = 0x189587Cd323613d65B37Af93940E9D3EB04EC274;

    // Roles (as defined in RoleManager)
    uint256 constant PROTOCOL_ADMIN = 2; // bit 1
    uint256 constant STRATEGY_ADMIN = 4; // bit 2
    uint256 constant RULES_ADMIN = 8; // bit 3
    uint256 constant STRATEGY_OPERATOR = 16; // bit 4
    uint256 constant KYC_OPERATOR = 32; // bit 5

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        RoleManager roleManager = RoleManager(ROLE_MANAGER);
        BasicStrategy strategy = BasicStrategy(payable(CLONED_STRATEGY));

        console2.log("=== Transfer to Multisig Script ===");
        console2.log("Multisig:", MULTISIG);
        console2.log("RoleManager:", address(roleManager));
        console2.log("Cloned Strategy:", address(strategy));
        console2.log("");

        // Pre-flight checks
        console2.log("Pre-flight checks:");
        console2.log("  Current RoleManager owner:", roleManager.owner());
        console2.log("  Current strategy manager:", strategy.manager());
        console2.log("  Current OLD_OWNER roles:", roleManager.rolesOf(OLD_OWNER));
        console2.log("  Current OLD_MANAGER_1 roles:", roleManager.rolesOf(OLD_MANAGER_1));
        console2.log("  Current OLD_MANAGER_2 roles:", roleManager.rolesOf(OLD_MANAGER_2));
        console2.log("  Current MULTISIG roles:", roleManager.rolesOf(MULTISIG));
        console2.log("");

        // Step 1: Grant roles to multisig
        console2.log("Step 1: Granting roles to multisig...");

        if (!roleManager.hasAnyRole(MULTISIG, PROTOCOL_ADMIN)) {
            roleManager.grantRole(MULTISIG, PROTOCOL_ADMIN);
            console2.log("  - Granted PROTOCOL_ADMIN");
        } else {
            console2.log("  - PROTOCOL_ADMIN already granted");
        }

        if (!roleManager.hasAnyRole(MULTISIG, STRATEGY_ADMIN)) {
            roleManager.grantRole(MULTISIG, STRATEGY_ADMIN);
            console2.log("  - Granted STRATEGY_ADMIN");
        } else {
            console2.log("  - STRATEGY_ADMIN already granted");
        }

        if (!roleManager.hasAnyRole(MULTISIG, RULES_ADMIN)) {
            roleManager.grantRole(MULTISIG, RULES_ADMIN);
            console2.log("  - Granted RULES_ADMIN");
        } else {
            console2.log("  - RULES_ADMIN already granted");
        }

        if (!roleManager.hasAnyRole(MULTISIG, STRATEGY_OPERATOR)) {
            roleManager.grantRole(MULTISIG, STRATEGY_OPERATOR);
            console2.log("  - Granted STRATEGY_OPERATOR");
        } else {
            console2.log("  - STRATEGY_OPERATOR already granted");
        }

        if (!roleManager.hasAnyRole(MULTISIG, KYC_OPERATOR)) {
            roleManager.grantRole(MULTISIG, KYC_OPERATOR);
            console2.log("  - Granted KYC_OPERATOR");
        } else {
            console2.log("  - KYC_OPERATOR already granted");
        }
        console2.log("");

        // Step 2: Transfer strategy manager
        console2.log("Step 2: Transferring strategy manager...");
        if (strategy.manager() != MULTISIG) {
            strategy.setManager(MULTISIG);
            console2.log("  - Strategy manager set to multisig");
        } else {
            console2.log("  - Strategy manager already set to multisig");
        }
        console2.log("");

        // Step 3: Verification
        console2.log("Step 3: Verifying transfers...");
        require(roleManager.hasAnyRole(MULTISIG, PROTOCOL_ADMIN), "Multisig missing PROTOCOL_ADMIN");
        require(roleManager.hasAnyRole(MULTISIG, STRATEGY_ADMIN), "Multisig missing STRATEGY_ADMIN");
        require(roleManager.hasAnyRole(MULTISIG, RULES_ADMIN), "Multisig missing RULES_ADMIN");
        require(roleManager.hasAnyRole(MULTISIG, STRATEGY_OPERATOR), "Multisig missing STRATEGY_OPERATOR");
        require(roleManager.hasAnyRole(MULTISIG, KYC_OPERATOR), "Multisig missing KYC_OPERATOR");
        require(strategy.manager() == MULTISIG, "Strategy manager not set to multisig");
        console2.log("  - All verifications passed");
        console2.log("");

        // Step 4: Revoke roles from old addresses (BEFORE transferring ownership)
        console2.log("Step 4: Revoking roles from old addresses...");

        // Revoke from OLD_OWNER
        if (roleManager.hasAnyRole(OLD_OWNER, PROTOCOL_ADMIN)) {
            roleManager.revokeRole(OLD_OWNER, PROTOCOL_ADMIN);
            console2.log("  - Revoked PROTOCOL_ADMIN from", OLD_OWNER);
        }
        if (roleManager.hasAnyRole(OLD_OWNER, STRATEGY_ADMIN)) {
            roleManager.revokeRole(OLD_OWNER, STRATEGY_ADMIN);
            console2.log("  - Revoked STRATEGY_ADMIN from", OLD_OWNER);
        }
        if (roleManager.hasAnyRole(OLD_OWNER, RULES_ADMIN)) {
            roleManager.revokeRole(OLD_OWNER, RULES_ADMIN);
            console2.log("  - Revoked RULES_ADMIN from", OLD_OWNER);
        }
        if (roleManager.hasAnyRole(OLD_OWNER, KYC_OPERATOR)) {
            roleManager.revokeRole(OLD_OWNER, KYC_OPERATOR);
            console2.log("  - Revoked KYC_OPERATOR from", OLD_OWNER);
        }

        // Revoke from OLD_MANAGER_1
        if (roleManager.hasAnyRole(OLD_MANAGER_1, PROTOCOL_ADMIN)) {
            roleManager.revokeRole(OLD_MANAGER_1, PROTOCOL_ADMIN);
            console2.log("  - Revoked PROTOCOL_ADMIN from", OLD_MANAGER_1);
        }
        if (roleManager.hasAnyRole(OLD_MANAGER_1, STRATEGY_ADMIN)) {
            roleManager.revokeRole(OLD_MANAGER_1, STRATEGY_ADMIN);
            console2.log("  - Revoked STRATEGY_ADMIN from", OLD_MANAGER_1);
        }
        if (roleManager.hasAnyRole(OLD_MANAGER_1, STRATEGY_OPERATOR)) {
            roleManager.revokeRole(OLD_MANAGER_1, STRATEGY_OPERATOR);
            console2.log("  - Revoked STRATEGY_OPERATOR from", OLD_MANAGER_1);
        }

        // Revoke from OLD_MANAGER_2
        if (roleManager.hasAnyRole(OLD_MANAGER_2, PROTOCOL_ADMIN)) {
            roleManager.revokeRole(OLD_MANAGER_2, PROTOCOL_ADMIN);
            console2.log("  - Revoked PROTOCOL_ADMIN from", OLD_MANAGER_2);
        }
        if (roleManager.hasAnyRole(OLD_MANAGER_2, STRATEGY_ADMIN)) {
            roleManager.revokeRole(OLD_MANAGER_2, STRATEGY_ADMIN);
            console2.log("  - Revoked STRATEGY_ADMIN from", OLD_MANAGER_2);
        }
        if (roleManager.hasAnyRole(OLD_MANAGER_2, STRATEGY_OPERATOR)) {
            roleManager.revokeRole(OLD_MANAGER_2, STRATEGY_OPERATOR);
            console2.log("  - Revoked STRATEGY_OPERATOR from", OLD_MANAGER_2);
        }
        console2.log("");

        // Step 5: Transfer RoleManager ownership (LAST - after revoking roles)
        console2.log("Step 5: Transferring RoleManager ownership to multisig...");
        if (roleManager.owner() != MULTISIG) {
            roleManager.transferOwnership(MULTISIG);
            console2.log("  - Ownership transferred to multisig");
        } else {
            console2.log("  - Ownership already transferred to multisig");
        }
        console2.log("");

        // Final verification
        console2.log("Step 6: Final verification...");
        require(roleManager.owner() == MULTISIG, "Ownership not transferred to multisig");
        require(
            !roleManager.hasAnyRole(
                OLD_OWNER, PROTOCOL_ADMIN | STRATEGY_ADMIN | RULES_ADMIN | STRATEGY_OPERATOR | KYC_OPERATOR
            ),
            "OLD_OWNER still has roles"
        );
        require(
            !roleManager.hasAnyRole(OLD_MANAGER_1, PROTOCOL_ADMIN | STRATEGY_ADMIN | STRATEGY_OPERATOR),
            "OLD_MANAGER_1 still has roles"
        );
        require(
            !roleManager.hasAnyRole(OLD_MANAGER_2, PROTOCOL_ADMIN | STRATEGY_ADMIN | STRATEGY_OPERATOR),
            "OLD_MANAGER_2 still has roles"
        );
        console2.log("  - Old addresses successfully revoked");
        console2.log("  - Ownership successfully transferred");
        console2.log("");

        console2.log("=== Transfer Complete ===");
        console2.log("RoleManager owner:", roleManager.owner());
        console2.log("Multisig roles:", roleManager.rolesOf(MULTISIG));
        console2.log("Strategy manager:", strategy.manager());
        console2.log("OLD_OWNER roles:", roleManager.rolesOf(OLD_OWNER));
        console2.log("OLD_MANAGER_1 roles:", roleManager.rolesOf(OLD_MANAGER_1));
        console2.log("OLD_MANAGER_2 roles:", roleManager.rolesOf(OLD_MANAGER_2));

        vm.stopBroadcast();
    }
}
