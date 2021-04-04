#!/bin/bash

echo 'eth.sendTransaction({from:eth.coinbase, to:"0x7Bb69d4F671a00eF80A94B66f3872F9211Dc163c", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc

echo 'eth.sendTransaction({from:eth.coinbase, to:"0x0ab49796127f3076Fb897390E5b312aD8992795C", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc

echo 'eth.sendTransaction({from:eth.coinbase, to:"0xC7d60Fe30a4d0Fc5ECC64c1803987D73b2b3Ba0A", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc

echo 'eth.sendTransaction({from:eth.coinbase, to:"0xa199983145358245E008dF521E0C9e8251867bE7", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc

echo 'eth.sendTransaction({from:eth.coinbase, to:"0x623654056820388CA12D2E65Da279177a725A34c", value: web3.toWei(10000, "ether")})' \
  | geth attach /tmp/geth.ipc
