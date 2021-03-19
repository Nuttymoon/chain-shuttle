should = require 'should'
truffleAssert = require 'truffle-assertions'
ChainShuttle = artifacts.require 'ChainShuttle'
FOOToken = artifacts.require 'FOOToken'

contract 'ChainShuttle', (accounts) ->
  shuttle = {}
  foo = {}

  before 'setup contract', ->
    shuttle = await ChainShuttle.deployed()
    foo = await FOOToken.deployed()

    await shuttle.setBridgeAddress shuttle.address

  describe 'setBrideAddress(address)', ->
    it 'when `address` is a contract, succeed', ->
      await shuttle.setBridgeAddress shuttle.address
      newAddress = await shuttle.bridgeAddress()
      newAddress.should.eql shuttle.address

    it 'when `address` is not a contract, revert transaction', ->
      await truffleAssert.reverts(shuttle.setBridgeAddress accounts[0])

  it 'registerTransfer', ->
    await foo.approve shuttle.address, 10000
    allowedTranfer = await foo.allowance accounts[0], shuttle.address
    allowedTranfer.toNumber().should.eql 10000

    # await shuttle.registerTransfer accounts[0], foo.address, 10000
    await foo.transferFrom accounts[0], shuttle.address, 10000
    shuttleBalance = await foo.balanceOf shuttle.addres
    shuttleBalance.should.eql 10000
    # firstTransfer = await shuttle.getOpenDeliveryTransfer(0)
    # firstTransfer.sender.should.eql accounts[0]
    # firstTransfer.recipient.should.eql accounts[0]
    # firstTransfer.amount.should.eql 10000
