#!/bin/bash

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[1;33m'
NC='\033[0m'

echo -e "=====[${ORANGE}OpenBanking.nr Compilation Script${NC}]====="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ARTIFACTS_PATH=$SCRIPT_DIR/../js/src/artifacts
COMPILED_CONTRACT_NAME=openbanking_escrow-OpenbankingEscrow.json
COMPILED_TOKEN_NAME=token-Token.json
TOKEN_CONTRACT_PATH=$HOME/nargo/github.com/nemi-fi/aztec-token/main
TOKEN_BYTECODE_PATH=$TOKEN_CONTRACT_PATH/target/token-Token.json
TXE_TOKEN_PATH=$SCRIPT_DIR/../contracts/openbanking-escrow/target/token-Token.json
CONTRACT_ACIR_PATH=$SCRIPT_DIR/../contracts/openbanking-escrow/target/$COMPILED_CONTRACT_NAME

NOIRUP_URL="https://raw.githubusercontent.com/noir-lang/noirup/main/install"
BBUP_URL="https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/master/barretenberg/bbup/install"
EXPECTED_NARGO_VERSION="1.0.0-beta.3"
EXPECTED_BB_VERSION="0..0"
EXPECTED_AZTEC_VERSION="0.85.0-alpha-testnet.2"

## Set the SED utility depending on OSX or Linix
if command -v gsed &> /dev/null
then
    # Set variable for gdate
    sed_cmd='gsed'
else
    # Set variable for date (Linux typically)
    sed_cmd='sed'
fi

## Set the node package installer based on availability
if command -v yarn >/dev/null 2>&1; then
    node_package_installer="yarn"
elif command -v pnpm >/dev/null 2>&1; then
    node_package_installer="pnpm"
else
    node_package_installer="npm"
fi

show_help() {
    echo -e "Usage: $0 [option]"
    echo -e "Example: ${ORANGE}$0 all${NC}"
    echo "Options:"
    echo -e "  ${ORANGE}all${NC}                 Compile circuit & contract ACIRs, ts artifact for contract, and add to js artifact dir"
    echo -e "  ${ORANGE}circuits${NC}            Compile only the circuit ACIR"
    echo -e "  ${ORANGE}contracts${NC}           Compile only the contract ACIR (TXE, won't put in js artifacts dir)"
    echo -e "  ${ORANGE}typescript${NC}          Generate TS bindings for the contract and build the ts library into JS"
    echo -e "  ${ORANGE}contract-artifacts${NC}  Compile the contract ACIR, generate TS bindings, and build the ts library into JS"
    exit 1
}

check_gsed() {
   # Only check on macOS
   if [[ "$(uname)" == "Darwin" ]]; then
       if ! command -v gsed &> /dev/null; then
           echo -e "${RED}ERROR: gsed not found!${NC}"
           echo -e "${BLUE}sed${NC} commands from this script will not work on mac natively - run ${ORANGE}brew install gnu-sed${NC} before proceeding"
           exit 1
       fi
   fi
}

### Dependencies Check
check_installer() {
    local NAME=$1
    local URI=$2
    if ! command -v $NAME >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} $NAME is not installed, installing..."
        temp_installer=$(mktemp)
        curl -s -L $URI > "$temp_installer"
        bash "$temp_installer"
        rm "$temp_installer"
    fi
    echo -e "${GREEN}✓${NC} $NAME is installed"

}

check_binary() {
    local NAME=$1 # name of the binary (nargo/bb)
    local INSTALLER=$2 # name of installer (noirup/bbup)
    local EXPECTED_VERSION=$3 # expected version
    local raw_version=$($NAME --version)

    if ! command -v $NAME >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} $NAME is not installed, installing..."
        $INSTALLER -v $EXPECTED_VERSION
    fi
    if echo "$raw_version" | grep -q "version ="; then
        version=$(echo "$raw_version" | grep "^$NAME version" | awk -F'=' '{print $2}' | tr -d ' ' | tr -d '\n')
    else
        version=$(echo "$raw_version" | tr -d '\n')
    fi
    if [ "$version" != "$EXPECTED_VERSION" ]; then
        echo -e "${RED}✗${NC} $NAME version $version is incorrect, installing version $EXPECTED_VERSION..."
        $INSTALLER -v $EXPECTED_VERSION
    fi
    echo -e "${GREEN}✓${NC} $NAME version $version is installed"
}

check_aztec() {
    if ! command -v aztec >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Aztec CLI is not installed, run ${ORANGE}bash -i <(curl -s https://install.aztec.network)${NC} before this script"
        return 1
    fi
    version=$(aztec -V | tr -d '\r\n')
    if [ "$version" != "$EXPECTED_AZTEC_VERSION" ]; then
        echo -e "${RED}✗${NC} Aztec CLI version ${RED}$version${NC} is incorrect, installing version ${GREEN}$EXPECTED_AZTEC_VERSION${NC}..."
        VERSION=$EXPECTED_AZTEC_VERSION aztec-up &> /dev/null
    fi
    echo -e "${GREEN}✓${NC} Aztec CLI version $version is installed"
}

compile_circuit() {
    # Dependencies
    check_installer "noirup" $NOIRUP_URL
    check_binary "nargo" "noirup" $EXPECTED_NARGO_VERSION
    check_installer "bbup" $BBUP_URL
    check_binary "bb" "bbup" $EXPECTED_BB_VERSION
    # Compile
    cd $SCRIPT_DIR/..
    echo -e "Compiling OpenBanking Domestic Payment Circuit..."
    nargo compile --force --silence-warnings
    CIRCUIT_SIZE=$(bb gates -b ./target/openbanking_domestic.json | grep "circuit" | grep -o '[0-9]\+')
    echo -e "${BLUE}OpenBanking Domestic Payment Circuit${NC} size: ${ORANGE}$CIRCUIT_SIZE${NC} gates"
    cp $SCRIPT_DIR/../target/openbanking_domestic.json $ARTIFACTS_PATH/circuits/openbanking_domestic.json
}

compile_contracts() {
    # Compile escrow contract
    echo "Compiling OpenBanking Escrow contract..."
    cd $SCRIPT_DIR/../contracts/openbanking-escrow
    aztec-nargo compile --force --silence-warnings


    # cd into token directory and compile
    cd $HOME/nargo/github.com/nemi-fi/aztec-token/main
    aztec-nargo compile --force --silence-warnings
    echo -e "${GREEN}✓${NC} Aztec Token $version is compiled"

    cp $TOKEN_BYTECODE_PATH $TXE_TOKEN_PATH
}

ts_artifacts() {
    # Ensure the sed commands will pass
    check_gsed

    # Generate TS artifacts
    echo "Generating TypeScript interface for OpenBanking Escrow and Token Contracts..."
    cd $SCRIPT_DIR/../contracts/openbanking-escrow
    aztec codegen ./target/$COMPILED_CONTRACT_NAME -o $ARTIFACTS_PATH/contracts
    aztec codegen ./target/$COMPILED_TOKEN_NAME -o $ARTIFACTS_PATH/contracts

    # Update import paths for JS library
    cp ./target/$COMPILED_CONTRACT_NAME $ARTIFACTS_PATH/contracts/openbanking_escrow.json
    $sed_cmd -i "s|../../../../contracts/openbanking-escrow/target/$COMPILED_CONTRACT_NAME|./openbanking_escrow.json|" $ARTIFACTS_PATH/contracts/OpenbankingEscrow.ts
    $sed_cmd -i "s|assert { type: 'json' }|with { type: 'json' }|" $ARTIFACTS_PATH/contracts/OpenbankingEscrow.ts
    $sed_cmd -i "/export const OpenBankingEscrowContractArtifact = loadContractArtifact(OpenBankingArtifactContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" $ARTIFACTS_PATH/contracts/OpenbankingEscrow.ts

    cp ./target/$COMPILED_TOKEN_NAME $ARTIFACTS_PATH/contracts/token.json
    $sed_cmd -i "s|../../../../contracts/openbanking-escrow/target/$COMPILED_TOKEN_NAME|./token.json|" $ARTIFACTS_PATH/contracts/Token.ts
    $sed_cmd -i "s|assert { type: 'json' }|with { type: 'json' }|" $ARTIFACTS_PATH/contracts/Token.ts
    $sed_cmd -i "/export const TokenContractArtifact = loadContractArtifact(TokenArtifactContractArtifactJson as NoirCompiledContract);/i \\/\/@ts-ignore" $ARTIFACTS_PATH/contracts/Token.ts

    # Build the library from ts to js
    cd $SCRIPT_DIR/../js
    echo "Building JS library..."
    rm -rf $SCRIPTS_DIR/../js/.tsbuildinfo
    rm -rf $SCRIPT_DIR/../js/dist
    $node_package_installer run build
}

if [ $# -eq 0 ]; then
    show_help
fi

# Process arguments
case "$1" in
    "all")
        compile_circuit
        compile_contracts
        ts_artifacts
        echo "Summary:"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking Domestic Payment Circuit ACIR to ${ORANGE}$ARTIFACTS_PATH/contractsopenbanking_domestic.json${NC}"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking Escrow Contract ACIR to ${ORANGE}$CONTRACT_ACIR_PATH${NC}"
        echo -e "   ${GREEN}✓${NC}   Copied Token Contract ACIR to ${ORANGE}$TXE_TOKEN_PATH${NC} for TXE"
        echo -e "   ${GREEN}✓${NC}   Copied OpenBanking Escrow Contract ACIR to ${ORANGE}$ARTIFACTS_PATH/contracts/openbanking_escrow.json${NC}"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking TS/JS Interface to ${ORANGE}$ARTIFACTS_PATH/contracts/OpenBanking.ts${NC}"
        echo -e "   ${GREEN}✓${NC}   Compiled TS library to JS library - add ${ORANGE}\"@openbanking.nr/js-inputs": "file:$SCRIPT_DIR/../js\",{NC} to your package.json to import"
        ;;
    "contracts")
        compile_contracts
        echo "Summary:"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking Escrow Contract ACIR to ${ORANGE}$CONTRACT_ACIR_PATH${NC}"
        echo -e "   ${GREEN}✓${NC}   Copied Token Contract ACIR to ${ORANGE}$TXE_TOKEN_PATH${NC} for TXE"
        ;;
    "circuits")
        compile_circuit
        echo "Summary:"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking Domestic Payment Circuit ACIR to ${ORANGE}$ARTIFACTS_PATH/circuits/openbanking_domestic.json${NC}"
        ;;
    "contract-artifacts")
        compile_contracts
        ts_artifacts
        echo "Summary:"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking Escrow Contract ACIR to ${ORANGE}$CONTRACT_ACIR_PATH${NC}"
        echo -e "   ${GREEN}✓${NC}   Copied Token Contract ACIR to ${ORANGE}$TXE_TOKEN_PATH${NC} for TXE"
        echo -e "   ${GREEN}✓${NC}   Copied OpenBanking Escrow Contract ACIR to ${ORANGE}$ARTIFACTS_PATH/contracts/openbanking_escrow.json${NC}"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking TS/JS Interface to ${ORANGE}$ARTIFACTS_PATH/contracts/OpenBanking.ts${NC}"
        echo -e "   ${GREEN}✓${NC}   Compiled TS library to JS library - add ${ORANGE}\"@openbanking.nr/js-inputs": "file:$SCRIPT_DIR/../js\",${NC} to your package.json dependencies to import"
        ;;
    "typescript")
        ts_artifacts
        echo "Summary:"
        echo -e "   ${GREEN}✓${NC}   Saved OpenBanking TS/JS Interface to ${ORANGE}$ARTIFACTS_PATH/contracts/OpenBanking.ts${NC}"
        echo -e "   ${GREEN}✓${NC}   Compiled TS library to JS library - add ${ORANGE}\"@openbanking.nr/js-inputs": "file:$SCRIPT_DIR/../js\",${NC} to your package.json dependencies to import"
        ;;
    *)
        echo "Error: Invalid argument '$1'"
        show_help
        ;;
esac
