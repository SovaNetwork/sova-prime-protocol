# cbBTC Refund Process

This directory contains scripts to refund cbBTC to depositors on Base mainnet.

## Overview

The refund process consists of three steps:
1. Run a dry run simulation to verify everything works
2. Execute the actual refunds on Base mainnet
3. Extract transaction hashes and generate a CSV report

## Files

- `RefundCBBTC.s.sol` - Foundry script that executes the refunds
- `extract-refund-txs.py` - Python script to extract transaction data and create CSV
- `extract-refund-txs.sh` - Shell script alternative for extraction (less reliable)

## Prerequisites

- Foundry installed (`forge`, `cast`)
- Python 3 (for CSV extraction)
- Private key with sufficient:
  - cbBTC balance: 0.00322216 cbBTC minimum
  - ETH for gas: ~0.005 ETH recommended
- Base mainnet RPC URL (e.g., Alchemy, Infura)

## Step-by-Step Instructions

### Step 1: Dry Run (Simulation)

First, verify the script works without broadcasting transactions:

```bash
forge script script/RefundCBBTC.s.sol:RefundCBBTCScript \
    --rpc-url https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY \
    --private-key $PRIVATE_KEY
```

**What to check:**
- ✅ Script compiles successfully
- ✅ Balance check passes
- ✅ All 27 depositors are processed
- ✅ Total amount matches expected: 0.00322216 cbBTC

### Step 2: Execute Refunds

Once the dry run succeeds, execute the actual refunds:

```bash
forge script script/RefundCBBTC.s.sol:RefundCBBTCScript \
    --rpc-url https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --slow
```

**Flags explained:**
- `--broadcast` - Actually send transactions to the network
- `--slow` - Wait for transaction confirmations (recommended)

**During execution:**
- The script will process each depositor sequentially
- Transaction hashes will be displayed in the console
- Results are saved to `broadcast/RefundCBBTC.s.sol/8453/run-latest.json`

**Expected output:**
```
======================================================================
cbBTC REFUND SCRIPT - Base Mainnet
======================================================================

Configuration:
  Token: cbBTC
  Address: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
  Network: Base Mainnet (Chain ID: 8453)

Admin Wallet:
  Address: 0x...
  cbBTC Balance: 0.00322216

Refund Summary:
  Total Depositors: 27
  Total to Refund: 0.00322216 cbBTC

Balance check: PASSED

======================================================================
PROCESSING REFUNDS
======================================================================

[1/27] Refunding 0x7013EC3aD66fB8CD09dD172D0CA231D6E6F3Baab
  Amount: 0.00116039 cbBTC
  Status: SUCCESS

[2/27] Refunding 0x465dE00594376d008E5fE91017fcE4E346Ac3365
  Amount: 0.00075670 cbBTC
  Status: SUCCESS

...

======================================================================
REFUND SUMMARY
======================================================================

Successful: 27
  Total Refunded: 0.00322216 cbBTC

======================================================================
```

### Step 3: Generate CSV Report

After successful execution, extract transaction data to CSV:

```bash
python3 script/extract-refund-txs.py
```

**Output:**
- Creates `refund-results-[timestamp].csv` in the project root
- Contains columns:
  - `Address` - Depositor Ethereum address
  - `Amount (cbBTC)` - Amount refunded in cbBTC
  - `Transaction Hash` - On-chain transaction hash
  - `Basescan URL` - Direct link to view transaction
  - `Status` - SUCCESS or error message

**Example CSV:**
```csv
Address,Amount (cbBTC),Transaction Hash,Basescan URL,Status
0x7013EC3aD66fB8CD09dD172D0CA231D6E6F3Baab,0.00116039,0xabc123...,https://basescan.org/tx/0xabc123...,SUCCESS
0x465dE00594376d008E5fE91017fcE4E346Ac3365,0.00075670,0xdef456...,https://basescan.org/tx/0xdef456...,SUCCESS
...
```

## Depositor List

Total depositors: **27**
Total amount: **0.00322216 cbBTC**

See `depositor.txt` for detailed breakdown of individual deposits.

## Safety Features

The script includes several safety mechanisms:

1. **Balance verification** - Checks admin has sufficient cbBTC before starting
2. **Dry run support** - Test without broadcasting transactions
3. **Error handling** - Try-catch blocks for each transfer
4. **Detailed logging** - Console output for every transaction
5. **Checksummed addresses** - EIP-55 validation prevents typos

## Troubleshooting

### "Insufficient cbBTC balance"
- Verify your wallet has at least 0.00322216 cbBTC
- Check you're using the correct private key

### "Compilation error: invalid checksum"
- Addresses are validated using EIP-55 checksumming
- This prevents sending to wrong addresses due to typos

### CSV shows "NOT_FOUND" for transactions
- The broadcast may have failed for some transactions
- Check `broadcast/RefundCBBTC.s.sol/8453/run-latest.json` for details
- You may need to manually retry failed addresses

### Python script fails
- Ensure you're in the project root directory
- Verify `broadcast/RefundCBBTC.s.sol/8453/` directory exists
- Check that `run-latest.json` was created after broadcast

## Gas Estimation

- **Per transaction:** ~50,000 gas
- **Total transactions:** 27
- **Total gas:** ~1,350,000 gas
- **Estimated cost** (at 0.1 gwei Base gas): ~0.000135 ETH (~$0.50)

## Security Notes

- **Never commit private keys** - Use environment variables
- **Test on testnet first** if possible
- **Verify recipient addresses** before broadcasting
- **Keep backups** of the CSV report for records

## Support

For issues or questions:
1. Check the Foundry documentation: https://book.getfoundry.sh/
2. Review broadcast logs in `broadcast/RefundCBBTC.s.sol/8453/`
3. Verify transactions on Basescan: https://basescan.org/

## License

UNLICENSED
