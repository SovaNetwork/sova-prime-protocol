#!/usr/bin/env bash

# Global constants for verification
verifier := "etherscan"
etherscan_api_key := "974M8F2BDI1U88P8VAHWUYZD3VRPVXNG4Q"

# Chain-specific settings
# Ethereum mainnet
# rpc_url := "https://ethereum-rpc.publicnode.com"
# verifier_url := "https://api.etherscan.io/v2/api?chainid=1"

# Base mainnet
rpc_url := "wss://base-rpc.publicnode.com"
verifier_url := "https://api.etherscan.io/v2/api?chainid=8453"

# Default recipe
default:
    @just --list

# Generate coverage report
coverage:
    @echo "Generating coverage data..."
    forge coverage --report lcov --report-file lcov.info
    @echo "Generating HTML report..."
    genhtml --ignore-errors inconsistent,corrupt lcov.info -o coverage-report --branch-coverage
    @echo "Opening report..."
    open coverage-report/index.html

# Verify contracts with optional deployment file
verify deployment_file="":
    #!/bin/bash
    set -euo pipefail

    # Find the latest deployment file
    if [ -z "{{deployment_file}}" ]; then
        LATEST_DEPLOYMENT=$(find $(pwd)/broadcast -name "run-latest.json" | grep -v "dry-run" | head -1)
    else
        LATEST_DEPLOYMENT="{{deployment_file}}"
    fi

    if [ -z "$LATEST_DEPLOYMENT" ]; then
        echo "Error: Could not find latest deployment file"
        exit 1
    fi

    echo "Using deployment file: $LATEST_DEPLOYMENT"

    # Function to verify a contract
    verify_contract() {
        local address=$1
        local contract_path=$2
        local contract_name=$3

        echo "Verifying $contract_name at $address..."

        forge verify-contract \
            --rpc-url {{rpc_url}} \
            --verifier {{verifier}} \
            --verifier-url "{{verifier_url}}" \
            --etherscan-api-key "{{etherscan_api_key}}" \
            $address \
            $contract_path:$contract_name

        # Add a small delay between verifications to avoid rate limiting
        sleep 2
    }

    # Function to find contract file path
    find_contract_path() {
        local contract_name=$1
        local result

        # Try to find the contract file in src directory
        result=$(find $(pwd)/src -type f -name "*.sol" -exec grep -l "contract $contract_name" {} \; | head -1)

        if [ -n "$result" ]; then
            # Convert absolute path to relative path from project root
            echo "${result#$(pwd)/}"
            return 0
        fi

        # If we get here, we couldn't find the contract file
        return 1
    }

    echo "Starting contract verification..."

    # Process the deployment file to extract contract information
    # Use jq if available, otherwise fallback to grep and awk
    if command -v jq &> /dev/null; then
        # First, process all main CREATE transactions
        echo "Processing main contract deployments..."
        echo
        jq -c '.transactions[] | select(.transactionType == "CREATE")' "$LATEST_DEPLOYMENT" | while read -r tx; do
            contract_name=$(echo "$tx" | jq -r '.contractName')
            contract_address=$(echo "$tx" | jq -r '.contractAddress')

            echo "Found deployed contract: $contract_name at $contract_address"

            # Find the contract's file path
            contract_path=$(find_contract_path "$contract_name")

            if [ -n "$contract_path" ]; then
                echo "Contract file found at: $contract_path"
                verify_contract "$contract_address" "$contract_path" "$contract_name"
            else
                echo "Warning: Could not find file for contract $contract_name. Skipping verification."
            fi
        done

        # Now, process all additionalContracts CREATE transactions
        echo "Processing additional contract deployments..."
        echo

        # Process each transaction with additionalContracts
        jq -c '.transactions[] | select(.additionalContracts != null and .additionalContracts != [])' "$LATEST_DEPLOYMENT" | while read -r tx; do
            # Get only the CREATE transactions from additionalContracts array
            create_contracts=$(echo "$tx" | jq -c '.additionalContracts[] | select(.transactionType == "CREATE")')

            # Process each CREATE transaction
            position=0
            echo "$create_contracts" | while read -r contract_info; do
                address=$(echo "$contract_info" | jq -r '.address')

                # Try to get the contract name directly from the JSON
                json_contract_name=$(echo "$contract_info" | jq -r '.contractName // empty')

                # Determine contract name and path
                contract_name=""
                contract_path=""

                # First, try to use the contract name from the JSON if available
                if [ -n "$json_contract_name" ] && [ "$json_contract_name" != "null" ]; then
                    potential_path=$(find_contract_path "$json_contract_name")
                    if [ -n "$potential_path" ]; then
                        contract_name="$json_contract_name"
                        contract_path="$potential_path"
                    fi
                fi

                # If we found a contract name and path, verify the contract
                if [ -n "$contract_name" ] && [ -n "$contract_path" ]; then
                    echo "Found additional deployed contract: $contract_name at $address (position $position)"
                    echo "Contract file found at: $contract_path"
                    verify_contract "$address" "$contract_path" "$contract_name"
                else
                    echo "Warning: Could not identify contract at $address (position $position). Skipping verification."
                fi

                # Increment position for next iteration
                position=$((position+1))
            done
        done
    else
        echo "jq not found, please install it."
        exit 1
    fi

    echo "Contract verification complete!"

# Build the project
build:
    forge build

# Run all tests
test:
    forge test

# Run tests with verbose output
test-verbose:
    forge test -vvv

# Run a specific test
test-match pattern:
    forge test --match-test {{pattern}}

# Format code
fmt:
    forge fmt

# Generate gas snapshot
snapshot:
    forge snapshot

# Deploy contracts (example)
deploy network network_url private_key:
    forge script script/DeployProtocol.s.sol:DeployProtocolScript --rpc-url {{network_url}} --private-key {{private_key}}

# Clean build artifacts
clean:
    forge clean

# Install dependencies
install:
    forge install

# Update dependencies
update:
    forge update