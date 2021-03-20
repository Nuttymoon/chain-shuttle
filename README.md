# Chain Shuttle

:bus: A shuttle to batch cross-chain transfers and lower fees.

## TO DO

- [x] Find a way to generate ERC20 token and send them to an address -> `$FOO` token
- [x] `registerTransfer()` should accept any ERC20 token
- [ ] `sendTransfers()` and `receiveTransfers()` functions
- [ ] Local bridge between the 2 chains
- [ ] Tokens addresses mapping between the 2 chains

## Setup

### Prerequisites

#### For Avalanche only

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
./scripts/bootstrap.sh -adcte
```

### Test the code

#### Ethereum (ganache-cli)

```sh
yarn migrate
yarn test
```

#### Avalanche (avash)

```sh
yarn migrate:avax
yarn test:avax
```

## Collaborate

Commits have to respect [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). They are enforced using [commitlint](https://github.com/conventional-changelog/commitlint) and [husky](https://github.com/typicode/husky).  
Use `npx cz` to easily generate commit messages (see [commitizen](https://github.com/commitizen/cz-cli)).
