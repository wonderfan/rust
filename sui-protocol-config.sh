#!/bin/bash

# ==============================================================================
# SUI PROTOCOL CONFIG TESTER
#
# This script fetches and displays the active on-chain protocol configuration
# for the Sui network (Devnet, Testnet, or Mainnet).
#
# The protocol configuration contains crucial parameters like transaction limits,
# gas fees, and feature flags that govern the network's operation.
#
# Usage:
#   ./sui_config_test.sh [NETWORK]
#
# Example:
#   ./sui_config_test.sh testnet
# ==============================================================================

# --- Configuration ---
SUI_CLI=$(which sui)
NETWORK=${1:-testnet} # Default to testnet if no argument is provided

# --- Helper Functions ---

# Function to check for required binary
check_prerequisites() {
    if [ ! -x "$SUI_CLI" ]; then
        echo "Error: 'sui' command not found or not executable."
        echo "Please ensure the Sui CLI is installed and in your PATH."
        exit 1
    fi
    echo "Sui CLI found at: $SUI_CLI"
}

# Function to display the protocol configuration
get_protocol_config() {
    echo "================================================================"
    echo "1. Fetching On-Chain Protocol Configuration for: $NETWORK"
    echo "================================================================"

    # The 'get-latest-protocol-config' command fetches the ProtocolConfigs
    # system object from the network and outputs it as JSON.
    CONFIG_JSON=$("$SUI_CLI" client get-latest-protocol-config --json --network "$NETWORK" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$CONFIG_JSON" ]; then
        echo "Error: Failed to fetch protocol configuration for '$NETWORK'."
        echo "Please check the network name or Sui client connection."
        exit 1
    fi

    echo "$CONFIG_JSON" > config_raw.json
    echo "Successfully fetched config (saved to config_raw.json)."

    # Use jq to extract key parameters for easy readability
    echo ""
    echo "================================================================"
    echo "2. Extracted Key Protocol Parameters"
    echo "================================================================"

    # --- Core Metadata ---
    echo "--- Metadata ---"
    PROTOCOL_VERSION=$(echo "$CONFIG_JSON" | jq -r '.protocol_version')
    MAX_TX_GAS=$(echo "$CONFIG_JSON" | jq -r '.max_tx_gas')
    MAX_PUB_TX_GAS=$(echo "$CONFIG_JSON" | jq -r '.max_tx_gas_for_public_transfer')
    MAX_INPUT_OBJECTS=$(echo "$CONFIG_JSON" | jq -r '.max_input_objects')
    
    echo "Active Protocol Version: $PROTOCOL_VERSION"
    echo "Max Gas for General TX: $MAX_TX_GAS"
    echo "Max Gas for Simple Transfer: $MAX_PUB_TX_GAS"
    echo "Max Input Objects per TX: $MAX_INPUT_OBJECTS"
    echo ""

    # --- Gas/Storage Parameters ---
    echo "--- Storage and Gas Fees (Cost Per Byte/Computation) ---"
    STORAGE_COST_PER_BYTE=$(echo "$CONFIG_JSON" | jq -r '.storage_gas_price')
    COMPUTATION_COST=$(echo "$CONFIG_JSON" | jq -r '.computation_gas_unit_price')

    echo "Storage Cost Per Byte (MIST): $STORAGE_COST_PER_BYTE"
    echo "Computation Gas Price (MIST/Unit): $COMPUTATION_COST"
    echo ""

    # --- Feature Flags ---
    echo "--- Key Feature Flags (Protocol Upgrade-Dependent) ---"
    # Note: These flags are usually part of the config and dictate active features.
    
    # We will look for an example config that might be a feature flag or a recent addition.
    # The actual fields change with protocol versions, so we use a general check.
    
    # Example: Check if a specific parameter related to object size is set
    MAX_OBJECT_SIZE=$(echo "$CONFIG_JSON" | jq -r '.max_move_object_size')
    
    if [ "$MAX_OBJECT_SIZE" != "null" ]; then
        echo "Maximum Move Object Size: $MAX_OBJECT_SIZE bytes (Feature active)"
    else
        echo "Maximum Move Object Size: Not explicitly defined in config (Using default)"
    fi

    # Display all configs for advanced inspection
    echo ""
    echo "================================================================"
    echo "3. Raw Config Keys (For Advanced Inspection)"
    echo "================================================================"
    echo "$CONFIG_JSON" | jq 'keys[]' | sed 's/"/ - /g'
    echo ""

    echo "Configuration retrieval complete. The network operates under these rules until the next epoch protocol upgrade."
}

# --- Main Execution ---
main() {
    check_prerequisites
    get_protocol_config
}

main "$@"
