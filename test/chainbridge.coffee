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

  describe 'setBrideAddress(_bridge)', ->
    it 'set `bridgeAddress` in contract state', ->
      await shuttle.setBridgeAddress shuttle.address
      newAddress = await shuttle.bridgeAddress()
      newAddress.should.eql shuttle.address

    it 'when `_bridge` is not a contract, revert transaction', ->
      await truffleAssert.reverts(shuttle.setBridgeAddress accounts[0])

  describe 'registerTransfer(_to, _token, _amount)', ->
    it 'register a new transfer', ->
      amount = 10000
      await foo.approve shuttle.address, amount
      allowedTranfer = await foo.allowance accounts[0], shuttle.address
      allowedTranfer.toNumber().should.eql amount

      await shuttle.registerTransfer accounts[0], foo.address, amount
      shuttleBalance = await foo.balanceOf shuttle.address
      shuttleBalance.toNumber().should.eql amount
      transferAmount = await shuttle.getTransferAmount accounts[0], accounts[0], foo.address
      transferAmount.toNumber().should.eql amount
    
    it 'when `_token` is not a contract, revert transaction', ->
      await truffleAssert.reverts(
        shuttle.registerTransfer accounts[0], accounts[0], 10000
      )

    it 'when `msg.sender` did not approve to withdraw `_amount`, revert transaction', ->
      await foo.approve shuttle.address, 0
      await truffleAssert.reverts(
        shuttle.registerTransfer accounts[0], foo.address, 10000
      )
