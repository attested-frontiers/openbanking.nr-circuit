#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ARTIFACTS_PATH=$SCRIPT_DIR/../js/src/artifacts/contracts
COMPILED_CONTRACT_NAME=openbanking_escrow-OpenbankingEscrow.json
TOKEN_BYTECODE_PATH=$SCRIPT_DIR/../js/node_modules/@aztec/noir-contracts.js/artifacts/token_contract-Token.json
TXE_TOKEN_PATH=$SCRIPT_DIR/../contracts/openbanking-escrow/target/token_contract-Token.json

cd $SCRIPT_DIR/../contracts/openbanking-escrow

aztec-nargo compile --force --silence-warnings
aztec codegen ./target/$COMPILED_CONTRACT_NAME -o $ARTIFACTS_PATH
cp ./target/$COMPILED_CONTRACT_NAME $ARTIFACTS_PATH
cp $TOKEN_BYTECODE_PATH $TXE_TOKEN_PATH
