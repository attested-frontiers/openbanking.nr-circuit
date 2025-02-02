#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

get_token_contract_bytecode() {
    token_bytecode_path="../../js/node_modules/@aztec/noir-contracts.js/artifacts/token_contract-Token.json"
    cp $token_bytecode_path "contracts/openbank-escrow/target/token_contract-Token.json"
    pwd
}

cd ../contracts/openbank-escrow
# aztec-nargo compile --force --silence-warnings
get_token_contract_bytecode