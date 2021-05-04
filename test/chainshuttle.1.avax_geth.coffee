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

contract 'ChainShuttle - init shuttle (dest chain)', (accounts) ->
  shuttle = {}
  taxi = {}
  bridge = {}
  Bridge.defaults({from: accounts[0]})
  Taxi.defaults({from: accounts[0]})
  depositNonce = 0

  it 'init shuttle contract on dest chain', ->
    shuttle = await ChainShuttle.at(staticAddr.avalanche.chainShuttle)
    bridge = await Bridge.at bridgeConf.chains[1].opts.bridge
    taxi = await Taxi.at bridgeConf.chains[1].info.erc20Address

    console.log """
                \t
                  ChainBridge address (Avalanche): #{bridge.address}
                  ChainShuttle address (Avalanche): #{shuttle.address}
                  TaxiToken address (Avalanche): #{taxi.address}

                  Registering ChainShuttle contract on the bridge...
                \t
                """

    await bridge.adminSetGenericResource(
      bridgeConf.chains[1].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
      shuttle.address
      '0x00000000'
      web3.eth.abi.encodeFunctionSignature 'offloadShuttle(bytes)'
    )

    for acc in accounts
      await taxi.mint acc, 1000000

    # Setup ChainShuttle to enable transfers
    await shuttle.setUpBridge(
      bridgeConf.chains[1].opts.bridge
      bridgeConf.chains[1].opts.erc20Handler
      '0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500'
      bridgeConf.chains[1].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
    )
    await shuttle.setCompany 0, 'ChainTaxi', 1, staticAddr.ethereum.chainShuttle, taxi.address
    await shuttle.initCapacity 0, 2

    newBridgeAddress = await shuttle.bridgeAddress()
    newBridgeAddress.should.eql bridgeConf.chains[1].opts.bridge
    newErc20HandlerAddress = await shuttle.erc20HandlerAddress()
    newErc20HandlerAddress.should.eql bridgeConf.chains[1].opts.erc20Handler
    newGenericHandlerAddress = await shuttle.genericHandlerAddress()
    newGenericHandlerAddress.should.eql bridgeConf.chains[1].opts.genericHandler
