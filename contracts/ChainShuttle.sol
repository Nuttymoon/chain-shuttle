// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ChainShuttle is Ownable {
    address public bridgeAddress;
    address public erc20HandlerAddress;
    bytes32 public erc20ResourceID;
    address public genericHandlerAddress;
    bytes32 public shuttleResourceID;

    struct Company {
        string name;
        uint8 destChainID;
        address mirror;
        address token;
    }

    struct Shuttle {
        uint16 companyID;
        uint16 capacity;
        uint16 numDeposits;
        uint256 totalAmount;
        address[] senders;
        mapping (address => address) sendersRecipients;
        mapping (address => uint256) sendersAmounts;
    }

    mapping (uint16 => Company) public companies;
    mapping (uint16 => Shuttle) public shuttles;
    uint16 public numShuttles;

    // companyID => (recipient => amount)
    mapping (uint16 => mapping (address => uint256)) claimableAmounts;

    event CompanyUpdate(
        uint16 indexed companyID,
        uint8 indexed destChainID,
        string name,
        address mirror,
        address token
    );
    event NewShuttle(
        uint16 indexed companyID,
        uint16 indexed shuttleID,
        uint16 capacity
    );
    event DepositRegistation(
        uint16 indexed companyID,
        uint16 indexed shuttleID,
        address indexed from,
        address to,
        uint256 amount
    );
    event ShuttleDeparture(
        uint16 indexed companyID,
        uint16 indexed shuttleID,
        uint256 totalAmount
    );
    event ShuttleOffload(
        uint16 indexed companyID,
        uint16 numDeposits
    );
    event DepositClaim(
        uint16 indexed companyID,
        address indexed recipient,
        uint256 amount 
    );

    modifier onlyBridgeSetUp {
        require(bridgeAddress != address(0), "Bridge address is not configured");
        require(erc20HandlerAddress != address(0), "Bridge address is not configured");
        require(genericHandlerAddress != address(0), "Bridge address is not configured");
        _;
    }

    modifier onlyGenericHandler {
        require(
            msg.sender == genericHandlerAddress,
            "Only the bridge GenericHandler can call this function"
        );
        _;
    }

    function setUpBridge(
        address _bridge,
        address _erc20Handler,
        bytes32 _erc20ResourceID,
        address _genericHandler,
        bytes32 _shuttleResourceID
    )
        public
        onlyOwner
    {
        require(Address.isContract(_bridge), "Bridge address must be a contract");
        require(Address.isContract(_erc20Handler), "ERC20Handler address must be a contract");
        // require(Address.isContract(_genericHandler), "GenericHandler address must be a contract");
        require(_erc20ResourceID != 0, "ERC20Handler ResourceID cannot be 0");
        require(_shuttleResourceID != 0, "GenericHandler ResourceID cannot be 0");
        bridgeAddress = _bridge;
        erc20HandlerAddress = _erc20Handler;
        erc20ResourceID = _erc20ResourceID;
        genericHandlerAddress = _genericHandler;
        shuttleResourceID = _shuttleResourceID;
    }

    function setCompany(
        uint16 _companyID,
        string memory _name,
        uint8 _destChainID,
        address _mirror,
        address _token
    )
        public
        onlyOwner
        onlyBridgeSetUp
        returns (uint16 companyID)
    {
        require(Address.isContract(_token), "ERC20 token address must be a contract");
        Company storage c = companies[_companyID];
        c.name = _name;
        c.destChainID = _destChainID;
        c.mirror = _mirror;
        c.token = _token;
        emit CompanyUpdate(companyID, _destChainID, _name, _mirror, _token);
    }

    function newShuttle(uint16 _companyID, uint16 _capacity)
        public
        onlyOwner
        onlyBridgeSetUp
        returns (uint16 shuttleID)
    {
        shuttleID = numShuttles++;
        Shuttle storage s = shuttles[shuttleID];
        s.companyID = _companyID;
        s.capacity = _capacity;
        emit NewShuttle(_companyID, shuttleID, _capacity);
    }

    function registerDeposit(uint16 _shuttleID, address _to, uint256 _amount)
        public
        payable
        onlyBridgeSetUp
    {
        require(_amount > 0, "Transfer amount has to be > 0");

        Shuttle storage s = shuttles[_shuttleID];
        Company storage c = companies[s.companyID];

        require(
            s.sendersRecipients[msg.sender] == address(0),
            "One sender cannot register more than one deposit per shuttle"
        );

        uint256 bridgeFee = abi.decode(Address.functionCall(
            bridgeAddress,
            abi.encodeWithSignature("_fee()")
        ), (uint256));
        require(msg.value == bridgeFee*2 / s.capacity, "Value has to be enough to pay the bridge");

        uint256 allowance = abi.decode(Address.functionCall(
            c.token,
            abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this))
        ), (uint256));
        require(allowance >= _amount, "Sender did not allow to withdraw enough tokens");

        bool successTransfer = abi.decode(Address.functionCall(
            c.token,
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                _amount
            )
        ), (bool));
        require(successTransfer, "Failed to transfer tokens from sender account");
        
        s.senders.push(msg.sender);
        s.sendersRecipients[msg.sender] = _to;
        s.sendersAmounts[msg.sender] = _amount;
        s.totalAmount += _amount;
        s.numDeposits++;

        emit DepositRegistation(s.companyID, _shuttleID, msg.sender, _to, _amount);

        if (s.numDeposits == s.capacity) {
            bool successApprove = abi.decode(Address.functionCall(
                c.token,
                abi.encodeWithSignature(
                    "approve(address,uint256)",
                    erc20HandlerAddress,
                    s.totalAmount
                )
            ), (bool));
            require(successApprove, "Failed to approve ERC20Handler");

            Address.functionCallWithValue(
                bridgeAddress,
                abi.encodeWithSignature(
                    "deposit(uint8,bytes32,bytes)",
                    c.destChainID,
                    erc20ResourceID,
                    abi.encodePacked(
                        abi.encode(s.totalAmount),
                        abi.encode(uint256(20)),
                        c.mirror
                    )
                ),
                bridgeFee,
                "Failed to send ERC20 tokens through the bridge"
            );

            Address.functionCallWithValue(
                bridgeAddress,
                abi.encodeWithSignature(
                    "deposit(uint8,bytes32,bytes)",
                    c.destChainID,
                    shuttleResourceID,
                    generateShuttleData(_shuttleID)
                ),
                bridgeFee,
                "Failed to send shuttle data through the bridge"
            );

            emit ShuttleDeparture(s.companyID, _shuttleID, s.totalAmount);

            for (uint16 send=0; send < s.numDeposits; send++) {
                delete(s.sendersRecipients[s.senders[send]]);
                delete(s.sendersAmounts[s.senders[send]]);
            }
            delete(s.senders);
            delete(s.numDeposits);
            delete(s.totalAmount);
        }
    }

    function generateShuttleData(uint16 _shuttleID)
        public
        view
        returns (bytes memory data)
    {
        Shuttle storage s = shuttles[_shuttleID];
        address[] memory recipients = new address[](s.capacity);
        uint256[] memory amounts = new uint256[](s.capacity);

        for (uint a=0; a < s.capacity; a++) {
            recipients[a] = s.sendersRecipients[s.senders[a]];
            amounts[a] = s.sendersAmounts[s.senders[a]];
        }

        return abi.encodePacked(
            // lenMetadata = capacity + companyID + capacity * 2 lists
            abi.encode(32 + 32 + s.capacity*2*32),
            abi.encode(s.capacity),
            abi.encode(s.companyID),
            recipients,
            amounts
        );
    }

    function offloadShuttle(bytes calldata _data) public onlyGenericHandler {
        uint256 numDeposits = abi.decode(_data, (uint256));
        uint16 companyID = abi.decode(_data[32:64], (uint16));
        // Skip depositer address and numDeposits
        uint256 dOffset = 64;
        uint256 aOffset = 64 + numDeposits*32;
        address recipient;
        uint256 amount;

        for (uint d=0; d < numDeposits; d++) {            
            recipient = abi.decode(_data[dOffset+d*32:dOffset+(d+1)*32], (address));
            amount = abi.decode(_data[aOffset+(d*32):aOffset+(d+1)*32], (uint256));
            claimableAmounts[companyID][recipient] += amount;
        }

        emit ShuttleOffload(companyID, uint16(numDeposits));
    }

    function claimDeposit(uint16 _companyID) public {
        uint256 amount = claimableAmounts[_companyID][msg.sender];
        require(amount > 0, "The claimable amount has to be > 0");

        Company storage c = companies[_companyID];

        bool successTransfer = abi.decode(Address.functionCall(
            c.token,
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                amount
            )
        ), (bool));
        require(successTransfer, "Failed to transfer tokens to recipient account");

        claimableAmounts[_companyID][msg.sender] = 0;

        emit DepositClaim(_companyID, msg.sender, amount);
    }

    function getClaimableAmount(uint16 _companyID, address _recipient)
        public
        view
        returns (uint256 amount)
    {
        return claimableAmounts[_companyID][_recipient];
    }

    function getCompany(uint16 _companyID)
        public
        view
        returns (
            string memory name,
            uint8 destChainID,
            address mirror,
            address token
        )
    {
        Company storage c = companies[_companyID];
        return (c.name, c.destChainID, c.mirror, c.token);
    }

    function getShuttle(uint16 _shuttleID)
        public
        view
        returns (uint16 companyID, uint16 capacity, uint16 numDeposits, uint256 totalAmount)
    {
        Shuttle storage s = shuttles[_shuttleID];
        return (s.companyID, s.capacity, s.numDeposits, s.totalAmount);
    }

    function getDeposit(uint16 _shuttleID, address _sender)
        public
        view
        returns (address recipient, uint256 amount)
    {
        Shuttle storage s = shuttles[_shuttleID];
        return (s.sendersRecipients[_sender], s.sendersAmounts[_sender]);
    }
}
