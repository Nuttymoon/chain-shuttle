# Chain Shuttle

:bus: A shuttle to batch cross-chain transfers and lower fees.

## TO DO

- [x] Find a way to generate ERC20 token and send them to an address -> `$TAXI` token generated by `cb-sol-cli`
- [x] `registerTransfer()` should accept any ERC20 token
- [x] ChainBridge
  - [x] Deploy contracts on 2 chains
  - [x] Setup `geth` instead of `ganache-cli`
  - [x] Setup ERC20 contracts as mintable/burnable
  - [x] Setup `chainsafe/chainbridge` Docker container
- [x] Refactor storage to be able to iterate through keys
- [x] Limit to 1 type of ERC20 token per deposit
- [ ] `sendShuttle()`
  - [ ] Allow ERC20Handler to withdraw from ChainBridge contract with `approve`
  - [ ] Call ChainBridge `deposit` function
- [ ] `dispatchDeposits()`
- [ ] Gas optimization
  - [ ] Configure realistic gas price
  - [ ] Benchmark `require` calls gas cost
  - [ ] Refund the user that payed gas for `sendShuttle()` (ERC20 token?)

## Setup

### Prerequisites

Install `cb-sol-cli`. See their [README.md](https://github.com/ChainSafe/chainbridge-deploy/tree/master/cb-sol-cli).

```sh
git clone https://github.com/ChainSafe/chainbridge-deploy.git
cd chainbridge-deploy/cb-sol-cli
yarn install
make install
```

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

Start 2 chains and setup the chainbridge:

```sh
yarn install
./env/bootstrap.sh -d -e geth -a geth -b
```

### Test the code

#### Ethereum (ganache-cli or geth)

```sh
yarn test
```

#### Avalanche (avash)

```sh
yarn test:avax
```

## Collaborate

Commits have to respect [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). They are enforced using [commitlint](https://github.com/conventional-changelog/commitlint) and [husky](https://github.com/typicode/husky).  
Use `npx cz` to easily generate commit messages (see [commitizen](https://github.com/commitizen/cz-cli)).

## Useful links

- [Solidity Contracts docs](https://docs.soliditylang.org/en/v0.8.2/contracts.html#)
- [OpenZeppelin Contracts docs](https://docs.openzeppelin.com/contracts/4.x/)
- [Go Ethereum docs](https://geth.ethereum.org/docs/)
- [Chainbridge docs](https://chainbridge.chainsafe.io/)
