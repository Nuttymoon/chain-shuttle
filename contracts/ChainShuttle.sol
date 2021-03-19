// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ChainShuttle is Ownable {
    // Enums
    enum DeliveryStatus { Loading, Closed, Delivered }
    DeliveryStatus constant defaultStatus = DeliveryStatus.Loading;

    // Structs
    struct Transfer {
        address sender;
        address recipient;
        uint256 amount;
    }

    struct Delivery {
        Transfer[] shipment;
        DeliveryStatus status;
        uint totalAmount;
    }

    // Public objects
    address public bridgeAddress;

    uint public transferBatch = 10;
    Delivery public openDelivery;
    // Delivery[] public pendingDeliveries;

    constructor() {
        resetOpenDelivery();
    }

    // Admin functions
    modifier onlyBridgeDefined {
        require(bridgeAddress != address(0), "Bridge address is not configured");
        _;
    }

    function setBridgeAddress(address _address) public onlyOwner {
        require(Address.isContract(_address), "Bridge address must be a contract");
        bridgeAddress = _address;
    }

    // Bridge functions
    function registerTransfer(
        address _recipient,
        address _tokenAddress,
        uint256 _amount
    ) public onlyBridgeDefined {
        require(Address.isContract(_tokenAddress), "The ERC20 token specified does not exist");
        require(_amount > 0, "The amount of money sent through the bridge has to be > 0");

        uint256 allowance = abi.decode(Address.functionCall(
            _tokenAddress,
            abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this))
        ), (uint256));
        require(allowance >= _amount, "You did not allow us to withdraw enough tokens");

        // bool success = abi.decode(Address.functionCall(
        //     _tokenAddress,
        //     abi.encodeWithSignature("transferFrom(address,address,uint265)",
        //                             msg.sender,
        //                             address(this),
        //                             _amount)
        // ), (bool));
        // require(success, "Failed to withdraw tokens from your account");
    
        // openDelivery.shipment.push(Transfer(msg.sender, _recipient, _amount));
    }

    function sendDelivery() public {
        require(address(this).balance >= openDelivery.totalAmount);
    }

    // Getter functions
    function getOpenDeliveryStatus() public view returns (DeliveryStatus) {
        return openDelivery.status;
    }

    function getOpenDeliveryTransfer(uint _index) public view returns (address, address, uint) {
        return (
            openDelivery.shipment[_index].sender,
            openDelivery.shipment[_index].recipient,
            openDelivery.shipment[_index].amount
        );
    }

    function resetOpenDelivery() private {
        openDelivery.status = defaultStatus;
        openDelivery.totalAmount = 0;
    }
}
