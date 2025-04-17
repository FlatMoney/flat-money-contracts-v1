#!/bin/bash

# Load the values from the .env file.
source .env

# Get chain id from the command line arguments.
CHAIN_ID=$1

if [[ -z $CHAIN_ID ]]; then
    echo "CHAIN_ID not provided"
    exit 1
fi

# Assign variables to the values from the .env file based on the chain id.
CHAIN_NAME_VAR="CHAIN_NAME_"$CHAIN_ID
CHAIN_NAME=${!CHAIN_NAME_VAR}

echo "Executing upgrades checker script"
pnpm run:oz script/tasks/check-upgrades.s.sol --rpc-url $CHAIN_NAME -vvv
