#!/bin/bash

# Bootstrap a local dev env
# -a = Create and configure a local Avalanche network using avash
# -e = Create and configure a local Ethereum network using ganache-cli
# -d = Destroy existing networks by killing Linux processes
# -c = Fund the Avalanche C-Chain address of the main account
# -t = Create and fund a Truffle account

avax_flag=''
eth_flag=''
destroy_flag=''
truffle_flag=''
cchain_flag=''

avax_user="cresus"
avax_pass="g9KDa3X8g3Rm8mLP"

avax_default_key="PrivateKey-ewoqjP7PxY4yr3iLTpLisriqt94hdyDFNgchSxGGztUrTXtNN"
avax_xp_addr="local18jma8ppw3nhx5r4ap8clazz0dps7rv5u00z96u"
avax_c_addr="0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC"
ganache_seed="chain-shuttle"

set -e

print_usage() {
  echo "Usage: bootstrap.sh -a -e -d -c -t"
}

destroy() {
  # Kill avash processes
  echo "Kill all Avalanche nodes..."
  while read proc; do
    kill -9 "$proc"
  done < <(ps aux | grep avash | grep -v grep | grep -oP '^\w+ *\d+' | grep -oP '\d+')

  # Kill ganache-cli process
  echo "Kill ganache-cli..."
  while read proc; do
    kill -9 "$proc"
  done < <(ps aux | grep ganache-cli | grep -v grep | grep -oP '^\w+ *\d+' | grep -oP '\d+')
}

start_avax() {
  # Start avash (Avalanche local)
  echo "Run avash..."
  cd "$GOPATH/src/github.com/ava-labs/avash" || exit 1
  echo "runscript scripts/five_node_staking.lua" | ./avash > /dev/null 2>&1 &

  echo "Wait for Avalanche nodes to start..."
  sleep 20

  # Create user in the keystore
  echo "Create $avax_user account in keystore..."
  curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"id\"     : 1,
    \"method\" : \"keystore.createUser\",
    \"params\" : {
      \"username\": \"$avax_user\",
      \"password\": \"$avax_pass\"
    }
  }" -H 'content-type:application/json;' 127.0.0.1:9650/ext/keystore

  # Link pre-funded addresses to user
  echo "Link $avax_user to pre-funded addresses..."
  echo "P-Chain..."
  curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"platform.importKey\",
    \"params\": {
      \"username\": \"$avax_user\",
      \"password\": \"$avax_pass\",
      \"privateKey\": \"$avax_default_key\"
    },
    \"id\": 1
  }" -H 'Content-Type: application/json' 127.0.0.1:9650/ext/platform
  echo "X-Chain..."
  curl -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"avm.importKey\",
    \"params\": {
      \"username\": \"$avax_user\",
      \"password\": \"$avax_pass\",
      \"privateKey\": \"$avax_default_key\"
    },
    \"id\": 1
  }" -H 'Content-Type: application/json' 127.0.0.1:9650/ext/bc/X
  echo "C-Chain..."
  curl -s -X POST --data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"avax.importKey\",
    \"params\": {
      \"username\": \"$avax_user\",
      \"password\": \"$avax_pass\",
      \"privateKey\": \"$avax_default_key\"
    },
    \"id\": 1
  }" -H 'Content-Type: application/json' 127.0.0.1:9650/ext/bc/C/avax

  cd - || exit 1
}

start_ethereum() {
  # Start Ganache (Ethereum local)
  echo "Run ganache-cli with seed '$ganache_seed'..."
  ganache-cli -d -m "$ganache_seed" > /dev/null 2>&1 &
}

fund_cchain() {
  # Send 100,000 AVAX to the C-chain
  echo "Move 100,000 AVAX to the C-chain..."
  curl -X POST --data "{
      \"jsonrpc\": \"2.0\", 
      \"id\"     : 1,                   
      \"method\" : \"avm.exportAVAX\",
      \"params\" : {                                      
          \"to\": \"C-$avax_xp_addr\",
          \"amount\": 100000000000000,
          \"username\":\"$avax_user\",
          \"password\":\"$avax_pass\"                             
      }
  }" -H 'content-type:application/json;' 127.0.0.1:9650/ext/bc/X
  sleep 2
  curl -X POST --data "{
      \"jsonrpc\": \"2.0\",
      \"id\"     : 1,
      \"method\" : \"avax.import\",
      \"params\" : {
          \"to\": \"$avax_c_addr\",
          \"sourceChain\": \"X\",
          \"username\": \"$avax_user\",  
          \"password\": \"$avax_pass\"
      }
  }" -H 'content-type:application/json;' 127.0.0.1:9650/ext/bc/C/avax
}

fund_truffle() {
  # Use truffle_accounts.js script to create and fund Truffle account
  truffle exec --network avax_local "$(dirname "$0")/truffle_accounts.js"
}

while getopts 'aedct' flag; do
  case "${flag}" in
    a) avax_flag='true' ;;
    e) eth_flag='true' ;;
    d) destroy_flag='true' ;;
    c) cchain_flag='true' ;;
    t) truffle_flag='true' ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [ "$destroy_flag" ]; then destroy; fi
if [ "$avax_flag" ]; then start_avax; fi
if [ "$cchain_flag" ]; then fund_cchain; fi
if [ "$truffle_flag" ]; then fund_truffle; fi
if [ "$eth_flag" ]; then start_ethereum; fi
