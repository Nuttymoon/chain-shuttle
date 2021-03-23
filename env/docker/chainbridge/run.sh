#!/bin/bash

export KEYSTORE_PASSWORD="chain-shuttle"

./bridge accounts import \
  --privateKey "0x2e722288a2eae86eb5a549c72a4dc45bd7fc737c6f52a32bdb4cde02ad37620c" \
  --password "$KEYSTORE_PASSWORD"

./bridge "$@"
