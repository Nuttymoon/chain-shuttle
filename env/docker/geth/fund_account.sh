#!/bin/bash

echo 'eth.sendTransaction({from:eth.coinbase, to:"0x4e979735c1f80011e7118d42204e15f392ef8e83", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc
