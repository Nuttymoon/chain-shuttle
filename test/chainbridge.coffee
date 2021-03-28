should = require 'should'
TruffleAssert = require 'truffle-assertions'
bridgeConf = require '../env/docker/chainbridge/.config.json'
erc20Json = require './resources/ERC20PresetMinterPauser.json'
ChainShuttle = artifacts.require 'ChainShuttle'
FOOToken = artifacts.require 'FOOToken'

contract 'ChainShuttle', (accounts) ->
  shuttle = {}
  foo = {}
  taxi = {}

  beforeEach 'setup contracts', ->
    shuttle = await ChainShuttle.deployed()
    foo = await FOOToken.deployed()

    taxi = new web3.eth.Contract(
      erc20Json.abi
      bridgeConf.chains[0].info.erc20Address
    )

    await shuttle.setUpBridge(
      bridgeConf.chains[0].opts.bridge
      "0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500"
      "0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00"
    )

    await shuttle.setUpMirror 1, shuttle.address

  describe 'setUpBridge(_bridge,_erc20HandlerID,_genericHandlerID)', ->
    it 'set up bridge params in contract state', ->
      await shuttle.setUpBridge(
        shuttle.address
        "0x0000000000000000000000000000000000000000000000000000000000000001"
        "0x0000000000000000000000000000000000000000000000000000000000000001"
      )
      newAddress = await shuttle.bridgeAddress()
      newAddress.should.eql shuttle.address
      newResourceID = await shuttle.erc20HandlerID()
      newResourceID.should.eql "0x0000000000000000000000000000000000000000000000000000000000000001"

    it 'when `_bridge` is not a contract, revert transaction', ->
      await TruffleAssert.reverts shuttle.setUpBridge(
        accounts[0]
        "0x000000000000000000000000000000e389d61c11e5fe32ec1735b3cd38c69500"
        "0x000000000000000000000000000000f44be64d2de895454c3467021928e55e00"
      )
  
  describe 'setUpMirror(_destChainID,_mirror)', ->
    it 'set up cross-chain mirror in contract state', ->
      await shuttle.setUpMirror 1, shuttle.address
      newAddress = await shuttle.mirrorAddress()
      newAddress.should.eql shuttle.address

  describe 'setTokenMapping(_mirror)', ->
    it 'add new mapping in contract state', ->
      await shuttle.setTokenMapping foo.address, foo.address
      mapping = await shuttle.getTokenMapping foo.address
      mapping.should.eql foo.address

  describe 'registerTransfer(_to, _token, _amount)', ->
    it 'register a new transfer', ->
      amount = 10000
      await taxi.methods.mint(
        accounts[0]
        1000000
      ).send {from: accounts[0]}
      await taxi.methods.approve(
        shuttle.address
        amount
      ).send {from: accounts[0]}
      allowedTranfer = await taxi.methods.allowance(
        accounts[0]
        shuttle.address
      ).call()

      result = await shuttle.registerTransfer(
        accounts[0]
        taxi._address
        amount
        {from: accounts[0], value: web3.utils.toWei('0.05', 'ether')}
      )
      transferAmount = await shuttle.getTransferAmount accounts[0], accounts[0], taxi._address
      transferAmount.toNumber().should.eql amount
      shuttleBalance = await taxi.methods.balanceOf(shuttle.address).call()
      Number(shuttleBalance).should.eql amount
      TruffleAssert.eventEmitted(result, 'TransferRegistered', {from: accounts[0]})
    
    it 'when `_token` is not a contract, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.registerTransfer accounts[0], accounts[0], 10000
      )

    it 'when `msg.sender` did not approve to withdraw `_amount`, revert transaction', ->
      await TruffleAssert.reverts(
        shuttle.registerTransfer accounts[0], taxi._address, 10000
      )
