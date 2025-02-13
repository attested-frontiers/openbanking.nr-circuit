#!/bin/bash

# make sure to run the docker containers in ../devnet first

# Get tunnels info from ngrok API
tunnels_json=$(curl -s localhost:4040/api/tunnels)

# Parse URLs using jq for each named tunnel
echo "Tunnel URLs:"
for tunnel in eth_rpc aztec_rpc; do
   url=$(echo $tunnels_json | jq -r ".tunnels[] | select(.name==\"$tunnel\") | .public_url")
   echo "$tunnel: $url"
done