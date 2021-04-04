should = require 'should'
TruffleAssert = require 'truffle-assertions'
bridgeConf = require '../env/docker/chainbridge/.config.json'
erc20Json = require './resources/ERC20PresetMinterPauser.json'
ChainShuttle = artifacts.require 'ChainShuttle'

contract 'ChainShuttle - setup functions', (accounts) ->
  shuttle = {}
  taxi = {}

  before ->
    # Load contracts
    shuttle = await ChainShuttle.deployed()
    taxi = new web3.eth.Contract(
      erc20Json.abi
      bridgeConf.chains[0].info.erc20Address
    )

  beforeEach ->
    await shuttle.setUpBridge(
      bridgeConf.chains[0].opts.bridge
      bridgeConf.chains[0].opts.erc20Handler
      '0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500'
      bridgeConf.chains[0].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
    )

  describe 'setUpBridge(_bridge,_erc20Handler,_erc20HandlerID,_genericHandler,_genericHandlerID)', ->
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
      newResourceID = await shuttle.erc20HandlerID()
      newResourceID.should.eql '0x0000000000000000000000000000000000000000000000000000000000000001'

    it 'when `_bridgeAddress` is not a contract, revert transaction', ->
      await TruffleAssert.reverts shuttle.setUpBridge(
        accounts[0]
        accounts[0]
        '0x0000000000000000000000000000000000000000000000000000000000000001'
        accounts[0]
        '0x0000000000000000000000000000000000000000000000000000000000000001'
      )
  
  describe 'newCompany(_name,_destChainID,_mirror,_localToken,_destToken)', ->
    it 'create a new company to transfer erc20 tokens', ->
      result = await shuttle.newCompany(
        'ChainTaxi'
        1
        shuttle.address
        taxi._address
        taxi._address
      )
      newCompany = await shuttle.getCompany 0
      newCompany.name.should.eql 'ChainTaxi'
      newCompany.destChainID.toNumber().should.eql 1
      newCompany.mirror.should.eql shuttle.address
      newCompany.localToken.should.eql taxi._address
      newCompany.destToken.should.eql taxi._address
      TruffleAssert.eventEmitted result, 'NewCompany', {companyID: web3.utils.toBN(0)}

    it 'when `_localToken` is not a contract, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.newCompany 'Revert', 1, accounts[0], accounts[0], accounts[0]
      )

  describe 'newShuttle(_companyID,_capacity)', ->
    it 'create a new shuttle to transfer erc20 tokens', ->
      result = await shuttle.newShuttle 0, 100
      newShuttle = await shuttle.getShuttle 0
      newShuttle.companyID.toNumber().should.eql 0
      newShuttle.capacity.toNumber().should.eql 100
      TruffleAssert.eventEmitted(
        result
        'NewShuttle'
        {
          shuttleID: web3.utils.toBN(0),
          companyID: web3.utils.toBN(0),
          capacity: web3.utils.toBN(100)
        }
      )

    it 'when `_companyID` does not exists, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.newShuttle 2, 10
      )

contract 'ChainShuttle - registerDeposit', (accounts) ->
  shuttle = {}
  taxi = {}

  before ->
    # Load contracts
    shuttle = await ChainShuttle.deployed()
    taxi = new web3.eth.Contract(
      erc20Json.abi
      bridgeConf.chains[0].info.erc20Address
    )
    await taxi.methods.mint(accounts[0], 1000000).send {from: accounts[0]}

    # Setup ChainShuttle to enable transfers
    await shuttle.setUpBridge(
      bridgeConf.chains[0].opts.bridge
      bridgeConf.chains[0].opts.erc20Handler
      '0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500'
      bridgeConf.chains[0].opts.genericHandler
      '0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00'
    )
    await shuttle.newCompany 'ChainTaxi', 1, shuttle.address, taxi._address, taxi._address
    await shuttle.newShuttle 0, 2

  describe 'registerDeposit(_shuttleID,_to,_amount)', ->
    it 'register a new erc20 deposit', ->
      amount = 10000
      await taxi.methods.approve(shuttle.address, amount).send {from: accounts[0]}

      result = await shuttle.registerDeposit(
        0, accounts[0], amount
        {from: accounts[0], value: web3.utils.toWei('0.025', 'ether')}
      )
      deposit = await shuttle.getDeposit 0, accounts[0]
      deposit.recipient.should.eql accounts[0]
      deposit.amount.toNumber().should.eql amount
      shuttleBalance = await taxi.methods.balanceOf(shuttle.address).call()
      Number(shuttleBalance).should.eql amount
      TruffleAssert.eventEmitted(
        result
        'DepositRegistered'
        {
          shuttleID: web3.utils.toBN(0),
          from: accounts[0],
          amount: web3.utils.toBN(amount)
        }
      )

  #   it 'register enough transfers to trigger a deposit on the bridge', ->
  #     amount = 10000
  #     await taxi.methods.mint(accounts[0], 1000000).send {from: accounts[0]}
  #     await taxi.methods.approve(shuttle.address, amount * 2).send {from: accounts[0]}
  #     allowedTranfer = await taxi.methods.allowance(accounts[0], shuttle.address).call()

  #     await shuttle.registerTransfer(
  #       accounts[0], taxi._address, amount
  #       {from: accounts[0], value: web3.utils.toWei('0.05', 'ether')}
  #     )
  #     result = await shuttle.registerTransfer(
  #       accounts[0], taxi._address, amount
  #       {from: accounts[0], value: web3.utils.toWei('0.05', 'ether')}
  #     )
  #     TruffleAssert.eventEmitted result, 'TokensSentToBridge'

  #     payload = await shuttle.getPayload(taxi._address)
  #     console.log(payload.toString())
    
    it 'when `msg.sender` has already registered a deposit in the shuttle, revert transaction', ->
      amount = 10000
      await taxi.methods.approve(shuttle.address, amount).send {from: accounts[0]}
      await TruffleAssert.reverts(
        shuttle.registerDeposit(
          0, accounts[0], amount
          {from: accounts[0], value: web3.utils.toWei('0.025', 'ether')}
        )
      )

    it 'when `msg.sender` did not approve to withdraw `_amount`, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.registerDeposit(
          0, accounts[1], 10000
          {from: accounts[1], value: web3.utils.toWei('0.025', 'ether')}
        )
      )
