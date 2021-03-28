// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ChainShuttle is Ownable {
    address public bridgeAddress;
    bytes32 public erc20HandlerID;
    bytes32 public genericHandlerID;

    uint8 public destChainID;
    address public mirrorAddress;

    uint8 public transferBatch = 10;
    uint8 public transferCount = 0;

    // 1 transfer = (sender => (recipient => (token => amount)))
    mapping(address => mapping(address => mapping(address => uint256))) public transfers;

    // Token address mapping between chains
    mapping (address => address) public tokensMapping;

    event TransferRegistered(address indexed from, address to, address token, uint256 amount);

    modifier onlyBridgeSetUp {
        require(bridgeAddress != address(0), "Bridge address is not configured");
        require(erc20HandlerID != 0, "ERC20Handler ResourceID is not configured");
        require(genericHandlerID != 0, "GenericHandler ResourceID address is not configured");
        _;
    }

    modifier onlyMirrorSetUp {
        require(mirrorAddress != address(0), "Mirror address is not configured");
        _;
    }

    function setUpBridge(address _bridge, bytes32 _erc20HandlerID, bytes32 _genericHandlerID)
        public
        onlyOwner
    {
        require(Address.isContract(_bridge), "Bridge address must be a contract");
        require(_erc20HandlerID != 0, "ERC20Handler ResourceID cannot be 0");
        require(_genericHandlerID != 0, "GenericHandler ResourceID cannot be 0");
        bridgeAddress = _bridge;
        erc20HandlerID = _erc20HandlerID;
        genericHandlerID = _genericHandlerID;
    }

    function setUpMirror(uint8 _destChainID, address _mirrorAddress) public onlyOwner {
        destChainID = _destChainID;
        mirrorAddress = _mirrorAddress;
    }

    function setTokenMapping(address _local, address _crossChain) public onlyOwner {
        tokensMapping[_local] = _crossChain;
    }

    // Bridge functions
    function registerTransfer(address _to, address _token, uint256 _amount)
        public
        payable
        onlyBridgeSetUp
        onlyMirrorSetUp
    {
        require(Address.isContract(_token), "ERC20 token address is not a contract");
        require(_amount > 0, "Transfer amount has to be > 0");

        uint256 bridgeFee = abi.decode(Address.functionCall(
            bridgeAddress,
            abi.encodeWithSignature("_fee()")
        ), (uint256));
        require(msg.value == bridgeFee, "Value has to be enough to pay the bridge");

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
        // require(successWithdraw, "Failed to withdraw tokens from sender account");
        
        transfers[msg.sender][_to][_token] = _amount;
        transferCount += 1;
        emit TransferRegistered(msg.sender, _to, _token, _amount);

        // if (transferCount == transferBatch) {

        // }
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
