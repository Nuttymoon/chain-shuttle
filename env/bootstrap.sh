#!/bin/bash

# Bootstrap a local dev env
# -a = Create and configure a local Avalanche network using avash
# -e = Create and configure a local Ethereum network using ganache-cli
# -d = Destroy existing networks by killing Linux processes
# -c = Fund the Avalanche C-Chain address of the main account
# -t = Create and fund a Truffle account
# -b = Setup ChainBridge between Avalanche and Ethereum chains

AVAX_PROVIDER=''
ETH_PROVIDER=''
DESTROY_FLAG=''
TRUFFLE_FLAG=''
CCHAIN_FLAG=''
BRIDGE_FLAG=''

# AVAX vars
AVAX_PORT=9650
export AVAX_URL="http://localhost:$AVAX_PORT"
AVASH_C_RPC_URL="$AVAX_URL/ext/bc/C/rpc"
AVASH_USER="cresus"
AVASH_PASS="g9KDa3X8g3Rm8mLP"
AVASH_PRIV_KEY="PrivateKey-ewoqjP7PxY4yr3iLTpLisriqt94hdyDFNgchSxGGztUrTXtNN"
AVASH_PRIV_KEY_HEX="0x56289e99c94b6912bfc12adc093c9b51124f0dc54ac7a766b2bc5ccf558d8027"
AVASH_XP_ADDR="local18jma8ppw3nhx5r4ap8clazz0dps7rv5u00z96u"
AVASH_C_ADDR="0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC"

# ETH vars
ETH_PORT=8545
export ETH_URL="http://localhost:$ETH_PORT"
GANACHE_SEED="chain-shuttle"
GANACHE_ADDR="0x4E979735C1f80011E7118D42204e15f392ef8e83"
GANACHE_PRIV_KEY="0x2e722288a2eae86eb5a549c72a4dc45bd7fc737c6f52a32bdb4cde02ad37620c"

# ChainBridge vars
ERC20_NAME="TAXI"

set -e

print_usage() {
  echo "Usage: bootstrap.sh [-a avash|geth] [-e ganache|geth] [-d] [-c] [-t] [-b]"
}

grey() {
  read input
  echo -e "\e[2m$input\e[0m"
}

destroy() {
  # Kill avash processes
  echo "Kill all avash nodes..."
  while read proc; do
    kill -9 "$proc"
  done < <(ps aux | grep avash | grep -vP 'grep|bootstrap' | grep -oP '^\w+ *\d+' | grep -oP '\d+')

  # Kill ganache-cli process
  echo "Kill ganache-cli..."
  while read proc; do
    kill -9 "$proc"
  done < <(ps aux | grep ganache-cli | grep -vP 'grep|bootstrap' | grep -oP '^\w+ *\d+' | grep -oP '\d+')
}

start_avash() {
  # Start avash (Avalanche local)
  echo "Run avash..."
  cd "$GOPATH/src/github.com/ava-labs/avash" || exit 1
  echo "runscript scripts/five_node_staking.lua" | ./avash > /dev/null &

  echo "Wait for avash nodes to start..."
  sleep 20

  # Create user in the keystore
  echo "Create $AVASH_USER account in keystore..."
  curl -s -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"id\"     : 1,
    \"method\" : \"keystore.createUser\",
    \"params\" : {
      \"username\": \"$AVASH_USER\",
      \"password\": \"$AVASH_PASS\"
    }
  }" -H 'content-type:application/json;' "$AVAX_URL/ext/keystore" | grey

  # Link pre-funded addresses to user
  echo "Link $AVASH_USER to pre-funded addresses..."
  echo "  P-Chain..."
  curl -s -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"platform.importKey\",
    \"params\": {
      \"username\": \"$AVASH_USER\",
      \"password\": \"$AVASH_PASS\",
      \"privateKey\": \"$AVASH_PRIV_KEY\"
    },
    \"id\": 1
  }" -H 'Content-Type: application/json' "$AVAX_URL/ext/platform" | grey
  echo "  X-Chain..."
  curl -s -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"avm.importKey\",
    \"params\": {
      \"username\": \"$AVASH_USER\",
      \"password\": \"$AVASH_PASS\",
      \"privateKey\": \"$AVASH_PRIV_KEY\"
    },
    \"id\": 1
  }" -H 'Content-Type: application/json' "$AVAX_URL/ext/bc/X" | grey
  echo "  C-Chain..."
  curl -s -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"avax.importKey\",
    \"params\": {
      \"username\": \"$AVASH_USER\",
      \"password\": \"$AVASH_PASS\",
      \"privateKey\": \"$AVASH_PRIV_KEY\"
    },
    \"id\": 1
  }" -H 'Content-Type: application/json' "$AVAX_URL/ext/bc/C/avax" | grey

  cd - > /dev/null || exit 1
}

start_ganache() {
  # Start Ganache (Ethereum local)
  # $1 = Port
  # $2 = Chain ID
  echo "Run ganache-cli with seed '$GANACHE_SEED'..."
  npx ganache-cli -p "$1" -d -m "$GANACHE_SEED" -g 20000000 -l 8000000 > /dev/null &
  echo "Wait for ganache-cli to start..."
  sleep 3
}

fund_cchain() {
  # Send 100,000 AVAX to the C-chain
  echo "Move 100,000 AVAX to the C-chain..."
  curl -s -X POST --data "{
      \"jsonrpc\": \"2.0\", 
      \"id\"     : 1,                   
      \"method\" : \"avm.exportAVAX\",
      \"params\" : {                                      
          \"to\": \"C-$AVASH_XP_ADDR\",
          \"amount\": 100000000000000,
          \"username\":\"$AVASH_USER\",
          \"password\":\"$AVASH_PASS\"                             
      }
  }" -H 'content-type:application/json;' "$AVAX_URL/ext/bc/X" | grey
  sleep 2
  curl -s -X POST --data "{
      \"jsonrpc\": \"2.0\",
      \"id\"     : 1,
      \"method\" : \"avax.import\",
      \"params\" : {
          \"to\": \"$AVASH_C_ADDR\",
          \"sourceChain\": \"X\",
          \"username\": \"$AVASH_USER\",  
          \"password\": \"$AVASH_PASS\"
      }
  }" -H 'content-type:application/json;' "$AVAX_URL/ext/bc/C/avax" | grey
}

fund_truffle() {
  # Use truffle_accounts.js script to create and fund Truffle account on avash chain
  truffle exec --network avax_avash "$(dirname "$0")/truffle_accounts.js"
}

deploy_bridge_contracts() {
  # Use cb-sol-cli to deploy ChainBridge contracts on one chain
  # $1 = Chain ID
  # $2 = URL
  # $3 = Private key
  # $4 = ERC20 token name
  echo "  Deploy ChainBridge Solidity contracts to chain..."
  cb_output=$(cb-sol-cli deploy --chainId "$1" --url "$2" \
    --bridge --erc20Handler --wetc --erc20 --erc20Symbol "$4" \
    --genericHandler --centAsset \
    --relayerThreshold 1 --privateKey "$3")
  echo -e "\e[2m$cb_output\e[0m"
  BRIDGE_ADDR=$(echo "$cb_output" | grep 'Bridge:' | grep -oP '0x\w+')
  ERC20_HANDLER_ADDR=$(echo "$cb_output" | grep 'Erc20 Handler:' | grep -oP '0x\w+')
  WETC_ADDR=$(echo "$cb_output" | grep 'WETC:' | grep -oP '0x\w+')
  ERC20_ADDR=$(echo "$cb_output" | grep 'Erc20:' | grep -oP '0x\w+')
  GEN_HANDLER_ADDR=$(echo "$cb_output" | grep 'Generic Handler:' | grep -oP '0x\w+')
  CENT_ADDR=$(echo "$cb_output" | grep 'Centrifuge Asset:' | grep -oP '0x\w+')
  echo "  Register resources on the Ethereum ChainBridge contract..."
  cb-sol-cli bridge register-resource \
    --url "$2" --privateKey "$3" --bridge "$BRIDGE_ADDR" \
    --resourceId "0x000000000000000000000000000000c76ebe4a02bbc34786d860b355f5a5ce00" \
    --targetContract "$WETC_ADDR"  --handler "$ERC20_HANDLER_ADDR" | grey
  cb-sol-cli bridge register-resource \
    --url "$2" --privateKey "$3" --bridge "$BRIDGE_ADDR" \
    --resourceId "0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500" \
    --targetContract "$ERC20_ADDR"  --handler "$ERC20_HANDLER_ADDR" | grey
  cb-sol-cli bridge register-generic-resource  \
    --url "$2" --privateKey "$3" --bridge "$BRIDGE_ADDR" \
    --resourceId "0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00" \
    --targetContract "$CENT_ADDR" --handler "$GEN_HANDLER_ADDR" \
    --hash --deposit "" --execute "store(bytes32)" | grey
}

setup_bridge() {
  # Setup ChainBridge between the local Avalanche and Ethereum chains
  # $1 Ethereum account private key
  # $2 Avalanche account private key
  echo "Contracts on Ethereum chain:"
  deploy_bridge_contracts 0 "$ETH_URL" "$1" "$ERC20_NAME"
  export ETH_BRIDGE_ADDR="$BRIDGE_ADDR"
  export ETH_ERC20_HANDLER_ADDR="$ERC20_HANDLER_ADDR"
  export ETH_GEN_HANDLER_ADDR="$GEN_HANDLER_ADDR"

  echo "Contracts on Avalanche chain:"
  deploy_bridge_contracts 1 "$AVAX_URL" "$2" "$ERC20_NAME"
  export AVAX_BRIDGE_ADDR="$BRIDGE_ADDR"
  export AVAX_ERC20_HANDLER_ADDR="$ERC20_HANDLER_ADDR"
  export AVAX_GEN_HANDLER_ADDR="$GEN_HANDLER_ADDR"

  echo "Generate ChainBridge JSON conf..."
  envsubst < "$(dirname "$0")/chainbridge/config-template.json" > "$(dirname "$0")/chainbridge/.config.json"
}

while getopts 'a:be:dct' flag; do
  case "${flag}" in
    a) AVAX_PROVIDER="$OPTARG" ;;
    b) BRIDGE_FLAG='true' ;;
    c) CCHAIN_FLAG='true' ;;
    d) DESTROY_FLAG='true' ;;
    e) ETH_PROVIDER="$OPTARG" ;;
    t) TRUFFLE_FLAG='true' ;;
    *) print_usage
       exit 1 ;;
  esac
done

avax_priv_key=''
eth_priv_key=''

if [[ "$DESTROY_FLAG" ]]; then destroy; fi
if [[ "$AVAX_PROVIDER" ]]
then
  case "$AVAX_PROVIDER" in
    avash) start_avash && avax_priv_key="$AVASH_PRIV_KEY_HEX" ;;
    ganache) start_ganache "$AVAX_PORT" && avax_priv_key="$GANACHE_PRIV_KEY";;
    *) echo "$AVAX_PROVIDER is not a supported Avalanche provider. Providers: avash, ganache"
       exit 1 ;;
  esac
fi
if [[ "$CCHAIN_FLAG" ]]; then fund_cchain; fi
if [[ "$TRUFFLE_FLAG" ]]; then fund_truffle; fi
if [[ "$ETH_PROVIDER" ]]
then
  case "$ETH_PROVIDER" in
    ganache) start_ganache "$ETH_PORT" && eth_priv_key="$GANACHE_PRIV_KEY" ;;
    *) echo "$ETH_PROVIDER is not a supported Ethereum provider. Providers: ganache"
       exit 1 ;;
  esac
fi
if [[ "$BRIDGE_FLAG" ]]
then
  if [[ "$AVAX_PROVIDER" && "$ETH_PROVIDER" ]]
  then
    setup_bridge "$eth_priv_key" "$avax_priv_key"
  else
    echo "Both Avalanche and Ethereum chains must be started to setup bridge"
    exit 1
  fi
fi
