#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

cd $SCRIPT_DIR/../js
echo "Removing old dist and .tsbuildinfo..."
rm -rf dist
rm .tsbuildinfo
yarn tsc

