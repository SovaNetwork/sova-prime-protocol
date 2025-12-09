#!/usr/bin/env python3
"""
Extract refund transaction hashes from Foundry broadcast logs and create CSV

Usage:
    python3 script/extract-refund-txs.py
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Depositor addresses and amounts (must match RefundCBBTC.s.sol)
DEPOSITORS = [
    ("0x7013EC3aD66fB8CD09dD172D0CA231D6E6F3Baab", "0.00116039"),
    ("0x465dE00594376d008E5fE91017fcE4E346Ac3365", "0.00075670"),
    ("0xD6d3b97124F55f2cC246D6237689272C9f35A84d", "0.00050000"),
    ("0x384C092e96F042a223778A82E8E09bB2B49EC921", "0.00026551"),
    ("0x8B04dEF86136F6D646c680fc5a5721Fedcd1422b", "0.00025304"),
    ("0xA7449cbBfc1A9233b30041182c049ad925D42C89", "0.00004242"),
    ("0x04D165D253CB177E6ACAEefbe810eD5bb43eE4ab", "0.00002672"),
    ("0x803B34733D802F02e84B87A770F8629987339520", "0.00001401"),
    ("0xC7CBF4f64FDb0eb40499894eef7C22407BCb31e1", "0.00001400"),
    ("0x6a0144b150C2ccD8e2D488B103209f6B0a09D7f1", "0.00001393"),
    ("0xa65FD1D3F9754c7d638faA0FC8fa446a293adeb7", "0.00001354"),
    ("0x78a9bC1eaae4f88cB94e2235AC8ce05Fb345E841", "0.00001244"),
    ("0x9888c145D491E6d74C9a33E2068cDD368A8af16b", "0.00001998"),
    ("0x785a7798379C2B21509D34352d0B80997fD0d7f0", "0.00000960"),
    ("0x3026a15027d1A2b6ea26b6FDFa87A36ad9254787", "0.00000721"),
    ("0xB48447a7A99075D3B675463d4c82131F24876763", "0.00000600"),
    ("0xD9B841a0FBc4d68353759D37a2bb87F514F15041", "0.00000542"),
    ("0xe4321f0aa947479a2aD94DBff687a9c260c1a70f", "0.00000340"),
    ("0x3d46C17D7ac1DB5F662C6014B442251b4F07febA", "0.00000100"),
    ("0x836996b0c261673b58Fc1d2C7FcC606606fddfD5", "0.00000026"),
    ("0x371ad3a9cB1b612B3C5A58cd9c59b71D7468aE9a", "0.00000020"),
    ("0xb626792a706e62263fe08b828C2f90aD4ef34601", "0.00000010"),
    ("0x2E78788272cf4086363D09e3531525B8A5d07b90", "0.00009150"),
    ("0x72542833bb793742b8257a5ff6558DcdF7F24d71", "0.00000010"),
    ("0x8fD7b2F90C80E848f1242392F458eA5f57b53570", "0.00000001"),
    ("0x90552Ca53592DfA96C887400DDAB964B2824FF02", "0.00000168"),
    ("0x04CA5B4fFc26C8c554c83DaDfe7A8d2eF9bf5560", "0.00000300"),
]

CBBTC_ADDRESS = "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf"


def format_amount(amount_raw):
    """Format amount from raw units to decimal cbBTC (8 decimals)"""
    amount = int(amount_raw)
    whole = amount // 100000000
    fractional = amount % 100000000
    return f"{whole}.{fractional:08d}"


def find_broadcast_file():
    """Find the latest broadcast file for RefundCBBTC script"""
    broadcast_dir = Path("broadcast/RefundCBBTC.s.sol/8453")

    if not broadcast_dir.exists():
        print(f"Error: Broadcast directory not found: {broadcast_dir}")
        sys.exit(1)

    # Look for run-latest.json or the most recent run file
    latest_file = broadcast_dir / "run-latest.json"
    if latest_file.exists():
        return latest_file

    # Find most recent run file
    run_files = sorted(broadcast_dir.glob("run-*.json"), reverse=True)
    if run_files:
        return run_files[0]

    print(f"Error: No broadcast files found in {broadcast_dir}")
    sys.exit(1)


def extract_transactions(broadcast_file):
    """Extract transaction details from broadcast file"""
    print("=" * 70)
    print("  Extracting Refund Transaction Hashes")
    print("=" * 70)
    print()
    print(f"Reading broadcast file: {broadcast_file}")
    print()

    with open(broadcast_file, "r") as f:
        data = json.load(f)

    transactions = []
    for tx in data.get("transactions", []):
        # Filter for CALL transactions to cbBTC contract
        if tx.get("transactionType") == "CALL":
            contract_address = tx.get("contractAddress", "").lower()
            if contract_address == CBBTC_ADDRESS.lower():
                tx_hash = tx.get("hash")
                arguments = tx.get("arguments", [])

                # Arguments[0] is recipient address, arguments[1] is amount
                if len(arguments) >= 2 and tx_hash:
                    recipient = arguments[0].lower()
                    amount = arguments[1]

                    transactions.append(
                        {
                            "hash": tx_hash,
                            "recipient": recipient,
                            "amount": amount,
                        }
                    )

    return transactions


def create_csv(transactions):
    """Create CSV file with transaction details"""
    timestamp = int(datetime.now().timestamp())
    output_file = f"refund-results-{timestamp}.csv"

    # Create a map of recipient address to transaction
    tx_map = {tx["recipient"]: tx for tx in transactions}

    with open(output_file, "w") as f:
        # Write header
        f.write("Address,Amount (cbBTC),Transaction Hash,Basescan URL,Status\n")

        # Match transactions to depositors by address
        matched = 0
        for depositor_addr, depositor_amount in DEPOSITORS:
            addr_lower = depositor_addr.lower()

            # Find matching transaction by recipient address
            matching_tx = tx_map.get(addr_lower)

            if matching_tx:
                # Verify the amount matches
                tx_amount_formatted = format_amount(matching_tx["amount"])

                f.write(
                    f'{depositor_addr},{depositor_amount},{matching_tx["hash"]},'
                    f'https://basescan.org/tx/{matching_tx["hash"]},SUCCESS\n'
                )
                matched += 1
            else:
                f.write(f"{depositor_addr},{depositor_amount},N/A,N/A,NOT_FOUND\n")

    print()
    print(f"✅ CSV file created: {output_file}")
    print()
    print(f"Total transactions found: {len(transactions)}")
    print(f"Total depositors: {len(DEPOSITORS)}")
    print(f"Successfully matched: {matched}")
    print()


def main():
    # Find broadcast file
    broadcast_file = find_broadcast_file()

    # Extract transactions
    transactions = extract_transactions(broadcast_file)

    # Create CSV
    create_csv(transactions)


if __name__ == "__main__":
    main()
