#!/bin/bash

# paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CURRENT_DIR=$(pwd)
TOKEN_BYTECODE_PATH=$SCRIPT_DIR/../js/node_modules/@aztec/noir-contracts.js/artifacts/token_contract-Token.json
TOKEN_TXE_DESTINATION=$SCRIPT_DIR/../contracts/openbank-escrow/target/token_contract-Token.json

# yarn for the js
cd $SCRIPT_DIR/../js
yarn

# check the version of aztec
EXPECTED_AZTEC_VERSION="0.72.1"
AZTEC_VERSION=$(aztec --version | tr -d '\r\n')
if [ "$AZTEC_VERSION" != "$EXPECTED_AZTEC_VERSION" ]; then
    echo "Aztec version mismatch, installing version $EXPECTED_AZTEC_VERSION"
    VERSION=$EXPECTED_AZTEC_VERSION aztec-up
fi

# compile the contracts
cd $SCRIPT_DIR/../contracts/openbank-escrow
aztec-nargo compile --force --silence-warnings

# copy the token bytecode to the target folder for txe
cp $TOKEN_BYTECODE_PATH $TOKEN_TXE_DESTINATION 

cd $CURRENT_DIR

