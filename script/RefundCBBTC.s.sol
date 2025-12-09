// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title RefundCBBTC
 * @notice Script to refund cbBTC to depositors on Base mainnet
 * @dev Usage:
 *
 *      Step 1: Run dry run (simulation):
 *      forge script script/RefundCBBTC.s.sol:RefundCBBTCScript \
 *          --rpc-url $BASE_RPC_URL \
 *          --private-key $PRIVATE_KEY
 *
 *      Step 2: Execute refunds on mainnet:
 *      forge script script/RefundCBBTC.s.sol:RefundCBBTCScript \
 *          --rpc-url $BASE_RPC_URL \
 *          --private-key $PRIVATE_KEY \
 *          --broadcast
 *
 *      Step 3: Extract transaction hashes to CSV:
 *      python3 script/extract-refund-txs.py
 *
 *      This will create a CSV file with columns:
 *      - Address: Depositor address
 *      - Amount (cbBTC): Amount refunded
 *      - Transaction Hash: On-chain transaction hash
 *      - Basescan URL: Direct link to transaction on Basescan
 *      - Status: SUCCESS or error message
 */
contract RefundCBBTCScript is Script {
    // cbBTC token address on Base mainnet
    address public constant CBBTC_ADDRESS = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    // Depositor addresses and amounts (aggregated from depositor.txt)
    struct Depositor {
        address account;
        uint256 amount; // in cbBTC base units (8 decimals)
    }

    // Array of all depositors with their total amounts
    Depositor[] public depositors;

    // Summary tracking
    uint256 public totalRefunded;
    uint256 public successfulRefunds;
    uint256 public failedRefunds;

    function setUp() public {
        // Initialize depositors array with aggregated amounts from depositor.txt
        // Total: 0.00322216 cbBTC across 27 depositors

        depositors.push(Depositor(0x7013EC3aD66fB8CD09dD172D0CA231D6E6F3Baab, 116039)); // 0.00116039
        depositors.push(Depositor(0x465dE00594376d008E5fE91017fcE4E346Ac3365, 75670));  // 0.00075670
        depositors.push(Depositor(0xD6d3b97124F55f2cC246D6237689272C9f35A84d, 50000));  // 0.00050000
        depositors.push(Depositor(0x384C092e96F042a223778A82E8E09bB2B49EC921, 26551));  // 0.00026551
        depositors.push(Depositor(0x8B04dEF86136F6D646c680fc5a5721Fedcd1422b, 25304));  // 0.00025304
        depositors.push(Depositor(0xA7449cbBfc1A9233b30041182c049ad925D42C89, 4242));   // 0.00004242
        depositors.push(Depositor(0x04D165D253CB177E6ACAEefbe810eD5bb43eE4ab, 2672));   // 0.00002672
        depositors.push(Depositor(0x803B34733D802F02e84B87A770F8629987339520, 1401));   // 0.00001401
        depositors.push(Depositor(0xC7CBF4f64FDb0eb40499894eef7C22407BCb31e1, 1400));   // 0.00001400
        depositors.push(Depositor(0x6a0144b150C2ccD8e2D488B103209f6B0a09D7f1, 1393));   // 0.00001393
        depositors.push(Depositor(0xa65FD1D3F9754c7d638faA0FC8fa446a293adeb7, 1354));   // 0.00001354
        depositors.push(Depositor(0x78a9bC1eaae4f88cB94e2235AC8ce05Fb345E841, 1244));   // 0.00001244
        depositors.push(Depositor(0x9888c145D491E6d74C9a33E2068cDD368A8af16b, 1998));   // 0.00001998
        depositors.push(Depositor(0x785a7798379C2B21509D34352d0B80997fD0d7f0, 960));    // 0.00000960
        depositors.push(Depositor(0x3026a15027d1A2b6ea26b6FDFa87A36ad9254787, 721));    // 0.00000721
        depositors.push(Depositor(0xB48447a7A99075D3B675463d4c82131F24876763, 600));    // 0.00000600
        depositors.push(Depositor(0xD9B841a0FBc4d68353759D37a2bb87F514F15041, 542));    // 0.00000542
        depositors.push(Depositor(0xe4321f0aa947479a2aD94DBff687a9c260c1a70f, 340));    // 0.00000340
        depositors.push(Depositor(0x3d46C17D7ac1DB5F662C6014B442251b4F07febA, 100));    // 0.00000100
        depositors.push(Depositor(0x836996b0c261673b58Fc1d2C7FcC606606fddfD5, 26));     // 0.00000026
        depositors.push(Depositor(0x371ad3a9cB1b612B3C5A58cd9c59b71D7468aE9a, 20));     // 0.00000020
        depositors.push(Depositor(0xb626792a706e62263fe08b828C2f90aD4ef34601, 10));     // 0.00000010
        depositors.push(Depositor(0x2E78788272cf4086363D09e3531525B8A5d07b90, 9150));   // 0.00009150
        depositors.push(Depositor(0x72542833bb793742b8257a5ff6558DcdF7F24d71, 10));     // 0.00000010
        depositors.push(Depositor(0x8fD7b2F90C80E848f1242392F458eA5f57b53570, 1));      // 0.00000001
        depositors.push(Depositor(0x90552Ca53592DfA96C887400DDAB964B2824FF02, 168));    // 0.00000168
        depositors.push(Depositor(0x04CA5B4fFc26C8c554c83DaDfe7A8d2eF9bf5560, 300));    // 0.00000300
    }

    function run() public {
        // Get private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);

        console.log("======================================================================");
        console.log("cbBTC REFUND SCRIPT - Base Mainnet");
        console.log("======================================================================");
        console.log("");

        // Load cbBTC contract
        IERC20 cbbtc = IERC20(CBBTC_ADDRESS);

        // Check admin balance
        uint256 adminBalance = cbbtc.balanceOf(admin);
        uint256 totalRequired = calculateTotalRequired();

        console.log("Configuration:");
        console.log("  Token: cbBTC");
        console.log("  Address:", CBBTC_ADDRESS);
        console.log("  Network: Base Mainnet (Chain ID: 8453)");
        console.log("");

        console.log("Admin Wallet:");
        console.log("  Address:", admin);
        console.log("  cbBTC Balance:", formatAmount(adminBalance));
        console.log("");

        console.log("Refund Summary:");
        console.log("  Total Depositors:", depositors.length);
        console.log("  Total to Refund:", formatAmount(totalRequired));
        console.log("");

        // Verify sufficient balance
        require(adminBalance >= totalRequired, "Insufficient cbBTC balance");
        console.log("Balance check: PASSED");
        console.log("");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        console.log("======================================================================");
        console.log("PROCESSING REFUNDS");
        console.log("======================================================================");
        console.log("");

        // Process each refund
        for (uint256 i = 0; i < depositors.length; i++) {
            Depositor memory depositor = depositors[i];
            processRefund(cbbtc, depositor, i);
        }

        vm.stopBroadcast();

        // Print final summary
        printSummary();

        console.log("To generate CSV report with transaction hashes, run:");
        console.log("  python3 script/extract-refund-txs.py");
        console.log("");
    }

    function processRefund(IERC20 cbbtc, Depositor memory depositor, uint256 index) internal {
        console.log("[%d/%d] Refunding %s", index + 1, depositors.length, depositor.account);
        console.log("  Amount: %s cbBTC", formatAmount(depositor.amount));

        try cbbtc.transfer(depositor.account, depositor.amount) returns (bool success) {
            if (success) {
                console.log("  Status: SUCCESS");
                totalRefunded += depositor.amount;
                successfulRefunds++;
            } else {
                console.log("  Status: FAILED - Transfer returned false");
                failedRefunds++;
            }
        } catch Error(string memory reason) {
            console.log("  Status: FAILED - %s", reason);
            failedRefunds++;
        } catch {
            console.log("  Status: FAILED - Unknown error");
            failedRefunds++;
        }
        console.log("");
    }

    function calculateTotalRequired() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            total += depositors[i].amount;
        }
        return total;
    }

    function printSummary() internal view {
        console.log("======================================================================");
        console.log("REFUND SUMMARY");
        console.log("======================================================================");
        console.log("");
        console.log("Successful: %d", successfulRefunds);
        console.log("  Total Refunded: %s cbBTC", formatAmount(totalRefunded));
        console.log("");

        if (failedRefunds > 0) {
            console.log("Failed: %d", failedRefunds);
            console.log("");
        }

        console.log("======================================================================");
    }

    function formatAmount(uint256 amount) internal pure returns (string memory) {
        // cbBTC has 8 decimals
        uint256 wholePart = amount / 1e8;
        uint256 fractionalPart = amount % 1e8;

        // Format with 8 decimal places
        return string(abi.encodePacked(
            vm.toString(wholePart),
            ".",
            padLeft(vm.toString(fractionalPart), 8)
        ));
    }

    function padLeft(string memory str, uint256 targetLength) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= targetLength) {
            return str;
        }

        bytes memory result = new bytes(targetLength);
        uint256 padding = targetLength - strBytes.length;

        for (uint256 i = 0; i < padding; i++) {
            result[i] = "0";
        }

        for (uint256 i = 0; i < strBytes.length; i++) {
            result[padding + i] = strBytes[i];
        }

        return string(result);
    }
}
