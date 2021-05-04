should = require 'should'
Contract = require '@truffle/contract'
TruffleAssert = require 'truffle-assertions'
bridgeConf = require '../env/docker/chainbridge/.config.json'
staticAddr = require '../env/.addresses.json'
erc20Json = require './contract-abis/ERC20PresetMinterPauser.json'
bridgeJson = require './contract-abis/Bridge.json'
ChainShuttle = artifacts.require 'ChainShuttle'

# Bridge contracts
Bridge = Contract {abi: bridgeJson.abi, unlinked_binary: bridgeJson.bytecode}
Bridge.setProvider web3.currentProvider
Taxi = Contract {abi: erc20Json.abi, unlinked_binary: erc20Json.bytecode}
Taxi.setProvider web3.currentProvider

contract 'ChainShuttle - cross-chain tests', (accounts) ->
  shuttle = {}
  taxi = {}
  bridge = {}
  Bridge.defaults({from: accounts[0]})
  Taxi.defaults({from: accounts[0]})
  depositNonce = 0

  before ->
    shuttle = await ChainShuttle.at(staticAddr.avalanche.chainShuttle)
    bridge = await Bridge.at bridgeConf.chains[1].opts.bridge
    taxi = await Taxi.at bridgeConf.chains[1].info.erc20Address

    console.log """
                \t
                  ChainBridge address: #{bridge.address}
                  ChainShuttle address (Avalanche): #{shuttle.address}
                  TaxiToken address: #{taxi.address}
                \t
                """

  it 'check shuttle contract balance after deposit', ->
    totalAmount = 20000
    shuttleBalance = await taxi.balanceOf shuttle.address
    shuttleBalance.toNumber().should.eql totalAmount

  it 'check that claimable deposits are registered', ->
    claim1 = await shuttle.claimableAmounts 0, accounts[0]
    claim1.toNumber().should.eql 10000
    claim2 = await shuttle.claimableAmounts 0, accounts[0]
    claim2.toNumber().should.eql 10000
