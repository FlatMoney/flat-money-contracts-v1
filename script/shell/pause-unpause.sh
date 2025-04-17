#!/bin/bash

# Load the values from the .env file.
source .env

# Access the first 3 command-line arguments.
CHAIN_ID=$1
ACTION=$2
MODE=$3

if [[ $MODE == "dry" ]]; then
    GAS_PRICE="" # Set the gas price to an empty string. This means the 3rd argument is not the gas price but rather a module name.
    shift 3 # Remove the first 3 arguments.
elif [[ $MODE == "broadcast" ]]; then
    GAS_PRICE=$4"gwei"
    shift 4 # Remove the first 4 arguments.
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

# Depending on the action, set the function signature to call the function in the script.
# Also encode the parameters for the function based on the action.
# Don't proceed if there is an error after calling cast.
if [[ $ACTION == "pause" ]]; then
    FUNC_SIG="0xf79db021"
    ENCODED_PARAMS=$(cast calldata "pauseViaSafe(string[])" "$MODULE_NAMES_FORMATTED" || exit 1)

elif [[ $ACTION == "unpause" ]]; then
    FUNC_SIG="0xc8c101fa"
    ENCODED_PARAMS=$(cast calldata "unpauseViaSafe(string[])" "$MODULE_NAMES_FORMATTED" || exit 1)
else
    echo "Invalid action"
    exit 1
fi

# Replace the first 4 bytes of the encoded parameters with the function signature.
ENCODED_PARAMS="${FUNC_SIG}${ENCODED_PARAMS:10}"

# Invoke the pnpm command to run the upgrade script depending on the mode.
if [[ $MODE == "dry" ]]; then
    echo "Executing script in dry-run mode"

    pnpm run:oz script/tasks/pause-unpause-module.s.sol \
    --sig $ENCODED_PARAMS\
    --rpc-url $CHAIN_NAME \
    --account $ACCOUNT_KEY \
    --sender $SENDER_ADDRESS \
    -vvv
elif [[ $MODE == "broadcast" ]]; then
    echo "Executing script in broadcast mode"

    if [[ -z $GAS_PRICE ]]; then
        echo "GAS_PRICE is not set"
        exit 1
    fi

    pnpm run:oz script/tasks/pause-unpause-module.s.sol \
    --sig $ENCODED_PARAMS \
    --rpc-url $CHAIN_NAME \
    --account $ACCOUNT_KEY \
    --sender $SENDER_ADDRESS \
    --priority-gas-price $GAS_PRICE \
    --broadcast --verify -vvv
fi
