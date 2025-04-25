#!/bin/bash

## Create node_modules directory if it doesn't exist
mkdir -p node_modules

## Remove existing aztec-scan-sdk from node_modules if it exists
if [ -d "node_modules/aztec-scan-sdk" ]; then
  rm -rf node_modules/aztec-scan-sdk
fi

## Clone and build aztec-scan-sdk
git clone --depth=1 --branch=main --single-branch https://github.com/aztec-scan/aztec-scan-sdk
cd aztec-scan-sdk
npm install
npm run build

## Move built files to node_modules
cd ..
cp -r aztec-scan-sdk node_modules/

## Clean up cloned repository
echo "Cleaning up..."
rm -rf aztec-scan-sdk