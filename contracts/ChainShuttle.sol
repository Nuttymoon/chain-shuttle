// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ChainShuttle is Ownable {
    address public bridgeAddress;

    // Address of the ChainShuttle contract on the target chain
    address public mirrorAddress;

    uint public transferBatch = 10;

    // 1 transfer = sender => (recipient => (token => amount))
    mapping (address => mapping (
        address => mapping (address => uint256)
    )) public transfers;

    // Token address mapping between chains
    mapping (address => address) public tokensMapping;

    event TransferRegistered(
        address indexed from,
        address to,
        address token,
        uint256 amount
    );

    modifier onlyBridgeSet {
        require(bridgeAddress != address(0), "Bridge address is not configured");
        _;
    }

    function setBridgeAddress(address _bridge) public onlyOwner {
        require(Address.isContract(_bridge), "Bridge address must be a contract");
        bridgeAddress = _bridge;
    }

    function setMirrorAddress(address _mirror) public onlyOwner {
        mirrorAddress = _mirror;
    }

    function setTokenMapping(address _local, address _crossChain) public onlyOwner {
        tokensMapping[_local] = _crossChain;
    }

    // Bridge functions
    function registerTransfer(address _to, address _token, uint256 _amount)
        public
        onlyBridgeSet
    {
        require(Address.isContract(_token), "ERC20 token address is not a contract");
        require(_amount > 0, "Transfer amount has to be > 0");

        uint256 allowance = abi.decode(Address.functionCall(
            _token,
            abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this))
        ), (uint256));
        require(allowance >= _amount, "Sender did not allow to withdraw enough tokens");

        bool successWithdraw = abi.decode(Address.functionCall(
            _token,
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                _amount
            )
        ), (bool));
        require(successWithdraw, "Failed to withdraw tokens from sender account");
        
        transfers[msg.sender][_to][_token] = _amount;
        emit TransferRegistered(msg.sender, _to, _token, _amount);
    }

    // Getter functions
    function getTransferAmount(address _from, address _to, address _token)
        public
        view
        returns (uint256)
    {
        return transfers[_from][_to][_token];
    }

    function getTokenMapping(address _local) public view returns (address) {
        return tokensMapping[_local];
    }
}
