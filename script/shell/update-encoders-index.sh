#!/bin/bash

# Get the directory of the script
SCRIPT_DIR="$(dirname "$0")"

# Directory containing the Solidity files
DIR="$SCRIPT_DIR/../deployment/encoders"

# File to modify
FILE="$DIR/Index.sol"

# Loop over all .encoder.sol files in the directory
for SOL_FILE in $DIR/*.encoder.sol
do
    # Extract the base name of the file
    BASENAME=$(basename $SOL_FILE)

    # Construct the import statement
    IMPORT_STATEMENT="import \"./$BASENAME\";"

    # Check if the import statement is already in the file
    if ! grep -Fxq "$IMPORT_STATEMENT" $FILE
    then
        # If the import statement is not in the file, append it after the pragma statement
        awk -v n=3 -v s="$IMPORT_STATEMENT" 'NR == n {print s} 1; END {if (NR < n) print s}' $FILE > tmp && mv tmp $FILE
    fi
done