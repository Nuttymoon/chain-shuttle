# Chain Shuttle

:bus: A shuttle to batch cross-chain transfers and lower fees.

## Setup

### Prerequisites

- Install Go and set `$GOPATH` in your env.
- Install and build [avalanchego](https://github.com/ava-labs/avalanchego) and [avash](https://github.com/ava-labs/avash) with sources:
  ```sh
  go get github.com/ava-labs/avash
  GO111MODULE=off go get github.com/ava-labs/avash
  GO111MODULE=off go get github.com/ava-labs/avalanchego
  cd $GOPATH/src/github.com/ava-labs/avalanchego
  ./scripts/buid.sh
  cd $GOPATH/src/github.com/ava-labs/avash
  go build
  ```

### Bootstrap dev env

```sh
yarn install
./scripts/bootstrap.sh -adct
```

### Test the env

```sh
truffle compile
truffle migrate --network local
```
