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

contract 'ChainShuttle - setup functions (source chain)', (accounts) ->
  shuttle = {}
  taxi = {}
  Taxi.defaults({from: accounts[0]})

  before ->
    # Load contracts
    shuttle = await ChainShuttle.deployed()
    taxi = await Taxi.at bridgeConf.chains[0].info.erc20Address

    console.log """
                \t
                  ChainShuttle address (Ethereum): #{shuttle.address}
                  TaxiToken address (Ethereum): #{taxi.address}
                \t
              """

  beforeEach ->
    await shuttle.setUpBridge(
      bridgeConf.chains[0].opts.bridge
      bridgeConf.chains[0].opts.erc20Handler
      '0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500'
      bridgeConf.chains[0].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
    )

  describe 'setUpBridge(_bridge,_erc20Handler,_erc20ResourceID,_genericHandler,_shuttleResourceID)', ->
    it 'set up bridge params in contract state', ->
      await shuttle.setUpBridge(
        shuttle.address
        shuttle.address
        '0x0000000000000000000000000000000000000000000000000000000000000001'
        shuttle.address
        '0x0000000000000000000000000000000000000000000000000000000000000001'
      )
      newBridgeAddress = await shuttle.bridgeAddress()
      newBridgeAddress.should.eql shuttle.address
      newErc20HandlerAddress = await shuttle.erc20HandlerAddress()
      newErc20HandlerAddress.should.eql shuttle.address
      newGenericHandlerAddress = await shuttle.genericHandlerAddress()
      newGenericHandlerAddress.should.eql shuttle.address
      newResourceID = await shuttle.erc20ResourceID()
      newResourceID.should.eql '0x0000000000000000000000000000000000000000000000000000000000000001'

    it 'when `_bridgeAddress` is not a contract, revert transaction', ->
      await TruffleAssert.reverts shuttle.setUpBridge(
        accounts[0]
        accounts[0]
        '0x0000000000000000000000000000000000000000000000000000000000000001'
        accounts[0]
        '0x0000000000000000000000000000000000000000000000000000000000000001'
      )
  
  describe 'setCompany(_name,_destChainID,_mirror,_token)', ->
    it 'create a new company to transfer erc20 tokens', ->
      result = await shuttle.setCompany(
        0
        'ChainTaxi'
        1
        shuttle.address
        taxi.address
      )
      newCompany = await shuttle.getCompany 0
      newCompany.name.should.eql 'ChainTaxi'
      newCompany.destChainID.toNumber().should.eql 1
      newCompany.mirror.should.eql shuttle.address
      newCompany.token.should.eql taxi.address
      TruffleAssert.eventEmitted result, 'CompanyUpdate', {companyID: web3.utils.toBN(0)}

    it 'when `_token` is not a contract, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.setCompany 1, 'Revert', 1, accounts[0], accounts[0]
      )

  describe 'initCapacity(_companyID,_capacity)', ->
    it 'allow a new shuttle capacity for a company and create the first shuttle', ->
      result = await shuttle.initCapacity 0, 100
      newShuttleID = await shuttle.activeShuttles 0, 100
      newShuttle = await shuttle.getShuttle newShuttleID.toNumber()
      newShuttle.companyID.toNumber().should.eql 0
      newShuttle.capacity.toNumber().should.eql 100
      newShuttle.status.toNumber().should.eql 0
      TruffleAssert.eventEmitted(
        result
        'CapacityInit'
        {companyID: web3.utils.toBN(0), capacity: web3.utils.toBN(100)}
      )
      TruffleAssert.eventEmitted(
        result
        'ShuttleCreation'
        {
          shuttleID: web3.utils.toBN(0),
          companyID: web3.utils.toBN(0),
          capacity: web3.utils.toBN(100)
        }
      )
    
contract 'ChainShuttle - shuttle functions (source chain)', (accounts) ->
  shuttle = {}
  taxi = {}
  bridge = {}
  Bridge.defaults({from: accounts[0]})
  Taxi.defaults({from: accounts[0]})
  depositNonce = 0

  before ->
    shuttle = await ChainShuttle.deployed()
    bridge = await Bridge.at bridgeConf.chains[0].opts.bridge
    taxi = await Taxi.at bridgeConf.chains[0].info.erc20Address

    console.log """
                \t
                  ChainBridge address (Ethereum): #{bridge.address}
                  ChainShuttle address (Ethereum): #{shuttle.address}
                  ChainShuttle address (Avalanche): #{staticAddr.avalanche.chainShuttle}
                  TaxiToken address (Ethereum): #{taxi.address}

                  Registering ChainShuttle contract on the bridge...
                \t
                """

    await bridge.adminSetGenericResource(
      bridgeConf.chains[0].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
      shuttle.address
      '0x00000000'
      web3.eth.abi.encodeFunctionSignature 'offloadShuttle(bytes)'
    )

    for acc in accounts
      await taxi.mint acc, 1000000

    # Setup ChainShuttle to enable transfers
    await shuttle.setUpBridge(
      bridgeConf.chains[0].opts.bridge
      bridgeConf.chains[0].opts.erc20Handler
      '0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500'
      bridgeConf.chains[0].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
    )
    await shuttle.setCompany 0, 'ChainTaxi', 1, staticAddr.avalanche.chainShuttle, taxi.address
    await shuttle.initCapacity 0, 2
      
  describe 'registerDeposit(_companyID,_capacity,_to,_amount)', ->
    it 'register a new erc20 deposit', ->
      amount = 10000
      await taxi.approve shuttle.address, amount

      result = await shuttle.registerDeposit(
        0, 2, accounts[0], amount
        {from: accounts[0], value: web3.utils.toWei('0.075', 'ether')}
      )
      deposit = await shuttle.getDeposit 0, accounts[0]
      deposit.recipient.should.eql accounts[0]
      deposit.amount.toNumber().should.eql amount
      shuttleBalance = await taxi.balanceOf shuttle.address
      shuttleBalance.toNumber().should.eql amount
      TruffleAssert.eventEmitted(
        result
        'DepositRegistration'
        {
          shuttleID: web3.utils.toBN(0),
          from: accounts[0],
          amount: web3.utils.toBN(amount)
        }
      )

    it 'when `msg.sender` has already registered a deposit in the shuttle, revert transaction', ->
      amount = 10000
      await taxi.approve shuttle.address, amount
      await TruffleAssert.reverts(
        shuttle.registerDeposit(
          0, 2, accounts[0], amount
          {from: accounts[0], value: web3.utils.toWei('0.075', 'ether')}
        )
      )

    it 'when `msg.sender` did not approve to withdraw `_amount`, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.registerDeposit(
          0, 2, accounts[1], 10000
          {from: accounts[1], value: web3.utils.toWei('0.075', 'ether')}
        )
      )

    it 'register enough transfers and trigger a deposit on the bridge', ->
      amount = 10000
      await taxi.approve shuttle.address, amount, {from: accounts[1]}

      result = await shuttle.registerDeposit(
        0, 2, accounts[1], amount
        {from: accounts[1], value: web3.utils.toWei('0.075', 'ether')}
      )
      TruffleAssert.eventEmitted(
        result
        'ShuttleBoardingComplete'
        {shuttleID: web3.utils.toBN(0), totalAmount: web3.utils.toBN(amount * 2)}
      )
      shuttleState = await shuttle.getShuttle 0
      shuttleState.status.toNumber().should.eql 1
      shuttleBalance = await taxi.balanceOf shuttle.address
      shuttleBalance.toNumber().should.eql 0
      bridgeEvents = await bridge.getPastEvents 'Deposit', {fromBlock: 0}
      depositNonce = bridgeEvents.pop().args.depositNonce.toNumber()

  describe 'sendShuttleData(_shuttleID,_depositNonce,_bridgeFee)', ->
    it 'send the shuttle data to trigger the offload', ->
      result = await shuttle.sendShuttleData 0, depositNonce, web3.utils.toWei('0.05', 'ether')
      shuttleState = await shuttle.getShuttle 0
      shuttleState.status.toNumber().should.eql 2

  describe 'offloadShuttle(_data)', ->
    it 'offload the shuttle data to register claimable deposits', ->
      # Setup accounts[0] as genericHandler to be able to call function
      await shuttle.setUpBridge(
        bridgeConf.chains[0].opts.bridge
        bridgeConf.chains[0].opts.erc20Handler
        '0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500'
        accounts[0]
        '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
      )

      shuttleData = "0x\
        0000000000000000000000000000000000000000000000000000000000000002\
        0000000000000000000000000000000000000000000000000000000000000000\
        0000000000000000000000000000000000000000000000000000000000000000\
        0000000000000000000000000000000000000000000000000000000000000000\
        #{accounts[0].substr(2).padStart(64, '0')}\
        #{accounts[1].substr(2).padStart(64, '0')}\
        0000000000000000000000000000000000000000000000000000000000002710\
        0000000000000000000000000000000000000000000000000000000000002710"

      result = await shuttle.offloadShuttle shuttleData
      claim1 = await shuttle.claimableAmounts 0, accounts[0]
      claim1.toNumber().should.eql 10000
      claim2 = await shuttle.claimableAmounts 0, accounts[0]
      claim2.toNumber().should.eql 10000
      TruffleAssert.eventEmitted(
        result
        'ShuttleOffload'
        {companyID: web3.utils.toBN(0), capacity: web3.utils.toBN(2)}
      )

    it 'if `msg.sender` is not the bridge GenericHandler, revert transaction', ->
      shuttleData = "0x\
        0000000000000000000000000000000000000000000000000000000000000002\
        0000000000000000000000000000000000000000000000000000000000000000\
        0000000000000000000000000000000000000000000000000000000000000000\
        0000000000000000000000000000000000000000000000000000000000000000\
        #{accounts[0].substr(2).padStart(64, '0')}\
        #{accounts[1].substr(2).padStart(64, '0')}\
        0000000000000000000000000000000000000000000000000000000000002710\
        0000000000000000000000000000000000000000000000000000000000002710"

      await TruffleAssert.reverts(shuttle.offloadShuttle shuttleData, {from: accounts[1]})
    
  describe 'claimDeposit(_companyID)', ->
    it 'claim a pending deposit', ->
      accBalanceBefore = await taxi.balanceOf accounts[0]
      await taxi.mint shuttle.address, 10000
      result = await shuttle.claimDeposit 0
      accBalanceAfter = await taxi.balanceOf accounts[0]
      (accBalanceAfter.toNumber() - accBalanceBefore.toNumber()).should.eql 10000
      TruffleAssert.eventEmitted(
        result
        'DepositClaim'
        {
          companyID: web3.utils.toBN(0),
          recipient: accounts[0],
          amount: web3.utils.toBN(10000)
        }
      )

    it 'if no available deposit, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.claimDeposit 0, {from: accounts[3]}
      )
