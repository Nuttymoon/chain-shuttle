#!/bin/bash

echo 'eth.sendTransaction({from:eth.coinbase, to:"0x7Bb69d4F671a00eF80A94B66f3872F9211Dc163c", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc
