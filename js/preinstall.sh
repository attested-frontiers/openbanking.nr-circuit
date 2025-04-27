#!/bin/bash

<<<<<<< HEAD
## Set Aztec NPM version
AZTEC_NPM_VERSION="=0.85.0-alpha-testnet.2"

## Check architecture and set SED_CMD
ARCH=$(uname)
if [[ "$ARCH" == "Linux" ]]; then
    SED_CMD="sed"
    echo "Linux detected, using standard sed"
elif [[ "$ARCH" == "Darwin" ]]; then
    # macOS detected
    echo "macOS detected, checking for gsed..."
    if command -v gsed >/dev/null 2>&1; then
        SED_CMD="gsed"
        echo "gsed is available, using gsed"
    else
        echo "Error: gsed is not installed on your macOS system."
        echo "Please install it using: brew install gnu-sed"
        exit 1
    fi
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

=======
>>>>>>> 8bbaba26522891b872700a70c900d0e86c5b59cc
## Create node_modules directory if it doesn't exist
mkdir -p node_modules

## Remove existing aztec-scan-sdk from node_modules if it exists
if [ -d "node_modules/aztec-scan-sdk" ]; then
  rm -rf node_modules/aztec-scan-sdk
fi

## Clone and build aztec-scan-sdk
git clone --depth=1 --branch=main --single-branch https://github.com/aztec-scan/aztec-scan-sdk
cd aztec-scan-sdk
<<<<<<< HEAD

## Replace aztec dependency versions in package.json
echo "Replacing Aztec package versions in package.json..."
$SED_CMD -i 's/"@aztec\/aztec.js": "[^"]*"/"@aztec\/aztec.js": "'$AZTEC_NPM_VERSION'"/g' package.json
$SED_CMD -i 's/"@aztec\/noir-contracts.js": "[^"]*"/"@aztec\/noir-contracts.js": "'$AZTEC_NPM_VERSION'"/g' package.json

=======
>>>>>>> 8bbaba26522891b872700a70c900d0e86c5b59cc
npm install
npm run build

## Move built files to node_modules
cd ..
cp -r aztec-scan-sdk node_modules/

## Clean up cloned repository
echo "Cleaning up..."
rm -rf aztec-scan-sdk