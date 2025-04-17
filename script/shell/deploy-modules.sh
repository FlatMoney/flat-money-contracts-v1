#!/bin/bash

# Load the values from the .env file.
source .env

# Access the first 2 command-line arguments.
CHAIN_ID=$1
MODE=$2

if [[ $MODE == "dry" || $MODE == "broadcast" ]]; then
    shift 2 # Remove the first 2 arguments.
else
    echo "Invalid mode"
    exit 1
fi

# Get the next command-line arguments and put them in an array.
# These arguments are the module names to be upgraded.
declare -a moduleNames
for arg in "$@"
do
    moduleNames+=("$arg")
done

# Format the module names as an array of comma separated strings.
MODULE_NAMES_FORMATTED=$(printf '\"%s\", ' "${moduleNames[@]}")
MODULE_NAMES_FORMATTED="[${MODULE_NAMES_FORMATTED%, }]"

# Assign variables to the values from the .env file based on the chain id.
CHAIN_NAME_VAR="CHAIN_NAME_"$CHAIN_ID
ACCOUNT_KEY_VAR="ACCOUNT_KEY_"$CHAIN_ID
SENDER_ADDRESS_VAR="SENDER_ADDRESS_"$CHAIN_ID
CHAIN_NAME=${!CHAIN_NAME_VAR}
ACCOUNT_KEY=${!ACCOUNT_KEY_VAR}
SENDER_ADDRESS=${!SENDER_ADDRESS_VAR}

# Function signature of the function "deployModules(string[])"
FUNC_SIG="0x7a21c2c3"

# Get abi-encoded parameters for the function.
# Don't proceed if there is an error after calling cast.
ENCODED_PARAMS=$(cast calldata "deployModules(string[])" "$MODULE_NAMES_FORMATTED" || exit 1)

# Replace the first 4 bytes of the encoded parameters with the function signature.
ENCODED_PARAMS="${FUNC_SIG}${ENCODED_PARAMS:10}"

# Invoke the pnpm command to run the upgrade script depending on the mode.
if [[ $MODE == "dry" ]]; then
    echo "Executing script in dry-run mode"

    pnpm run:oz script/tasks/deploy-module.s.sol \
    --sig $ENCODED_PARAMS\
    --rpc-url $CHAIN_NAME \
    --account $ACCOUNT_KEY \
    --sender $SENDER_ADDRESS \
    -vvv
    
elif [[ $MODE == "broadcast" ]]; then
    echo "Executing script in broadcast mode"

    pnpm run:oz script/tasks/deploy-module.s.sol \
    --sig $ENCODED_PARAMS \
    --rpc-url $CHAIN_NAME \
    --account $ACCOUNT_KEY \
    --sender $SENDER_ADDRESS \
    --broadcast --verify -vvv
fi
