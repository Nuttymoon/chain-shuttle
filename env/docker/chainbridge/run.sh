#!/bin/bash

export KEYSTORE_PASSWORD="chainshuttle"

./bridge accounts import \
  --privateKey "0xe6d41e023189809776529d270f118a883fd7acd5b6bf958c4c8ead37493034e9" \
  --password "$KEYSTORE_PASSWORD"

./bridge "$@"
