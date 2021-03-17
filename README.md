# Chain Shuttle

:bus: A shuttle to batch cross-chain transfers and lower fees.

## TO DO

- [x] Find a way to generate ERC20 token and send them to an address -> `$FOO` token
- [ ] `registerTransfer()` should accept any ERC20 token
- [ ] Log errors using [events](https://docs.soliditylang.org/en/v0.8.2/contracts.html#events)

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
truffle migrate --network avax_local
```

## Collaborate

Commits have to respect [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). They are enforced using [commitlint](https://github.com/conventional-changelog/commitlint) and [husky](https://github.com/typicode/husky).  
Use `npx cz` to easily generate commit messages (see [commitizen](https://github.com/commitizen/cz-cli)).
