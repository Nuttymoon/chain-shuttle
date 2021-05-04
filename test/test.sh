#!/bin/bash

set -e

echo ""
# Deploy contracts to static addresses
"$(pwd)/$(dirname "$0")/../env/bootstrap.sh" "-m"

# Run each test file in order and on the right network
while read -r script
do
  network=$(echo "$script" | grep -oP '(avax_geth)|(eth)')
  echo "Running $script..."
  truffle test "$(dirname "$0")/$script" --network "$network"
done <<< "$(ls "$(dirname "$0")" | grep '.js')"
