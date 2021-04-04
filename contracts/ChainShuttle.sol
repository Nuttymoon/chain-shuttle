// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ChainShuttle is Ownable {
    address public bridgeAddress;
    address public erc20HandlerAddress;
    bytes32 public erc20HandlerID;
    address public genericHandlerAddress;
    bytes32 public genericHandlerID;

    struct Company {
        string name;
        uint8 destChainID;
        address mirror;
        address localToken;
        address destToken;
    }

    struct Shuttle {
        uint16 companyID;
        uint16 capacity;
        uint16 numDeposits;
        uint256 totalAmount;
        address[] senders;
        mapping (address => address) sendersRecipients;
        mapping (address => uint) sendersAmounts;
    }

    mapping (uint16 => Company) public companies;
    mapping (uint16 => Shuttle) public shuttles;
    uint16 public numCompanies;
    uint16 public numShuttles;

    event NewCompany(
        uint16 indexed companyID,
        uint8 indexed destChainID,
        string name,
        address token
    );
    event NewShuttle(
        uint16 indexed companyID,
        uint16 indexed shuttleID,
        uint16 capacity
    );
    event DepositRegistered(
        uint16 indexed companyID,
        uint16 indexed shuttleID,
        address indexed from,
        address to,
        uint256 amount
    );
    event TokensSentToBridge();

    modifier onlyBridgeSetUp {
        require(bridgeAddress != address(0), "Bridge address is not configured");
        require(erc20HandlerAddress != address(0), "Bridge address is not configured");
        require(genericHandlerAddress != address(0), "Bridge address is not configured");
        _;
    }

    function setUpBridge(
        address _bridge,
        address _erc20Handler,
        bytes32 _erc20HandlerID,
        address _genericHandler,
        bytes32 _genericHandlerID
    )
        public
        onlyOwner
    {
        require(Address.isContract(_bridge), "Bridge address must be a contract");
        require(Address.isContract(_erc20Handler), "ERC20Handler address must be a contract");
        require(Address.isContract(_genericHandler), "GenericHandler address must be a contract");
        require(_erc20HandlerID != 0, "ERC20Handler ResourceID cannot be 0");
        require(_genericHandlerID != 0, "GenericHandler ResourceID cannot be 0");
        bridgeAddress = _bridge;
        erc20HandlerAddress = _erc20Handler;
        erc20HandlerID = _erc20HandlerID;
        genericHandlerAddress = _genericHandler;
        genericHandlerID = _genericHandlerID;
    }

    function newCompany(
        string memory _name,
        uint8 _destChainID,
        address _mirror,
        address _localToken,
        address _destToken
    )
        public
        onlyOwner
        onlyBridgeSetUp
        returns (uint16 companyID)
    {
        require(Address.isContract(_localToken), "ERC20 token address must be a contract");
        companyID = numCompanies++;
        Company storage c = companies[companyID];
        c.name = _name;
        c.destChainID = _destChainID;
        c.mirror = _mirror;
        c.localToken = _localToken;
        c.destToken = _destToken;
        emit NewCompany(companyID, _destChainID, _name, _localToken);
    }

    function newShuttle(uint16 _companyID, uint16 _capacity)
        public
        onlyOwner
        onlyBridgeSetUp
        returns (uint16 shuttleID)
    {
        require(_companyID < numCompanies, "The shuttle company does not exist");
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
        require(msg.value == bridgeFee / s.capacity, "Value has to be enough to pay the bridge");

        uint256 allowance = abi.decode(Address.functionCall(
            c.localToken,
            abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this))
        ), (uint256));
        require(allowance >= _amount, "Sender did not allow to withdraw enough tokens");

        bool successWithdraw = abi.decode(Address.functionCall(
            c.localToken,
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                _amount
            )
        ), (bool));
        require(successWithdraw, "Failed to withdraw tokens from sender account");
        
        s.senders.push(msg.sender);
        s.sendersRecipients[msg.sender] = _to;
        s.sendersAmounts[msg.sender] = _amount;
        s.numDeposits++;

        emit DepositRegistered(s.companyID, _shuttleID, msg.sender, _to, _amount);
    }

    // function depositTransfers(uint256 _fee)
    //     internal
    //     onlyBridgeSetUp
        // onlyMirrorSetUp
    // {
        // bool successApprove = abi.decode(Address.functionCall(
        //     _token,
        //     abi.encodeWithSignature(
        //         "approve(address,uint256)",
        //         erc20HandlerAddress,
        //         transferTotal
        //     )
        // ), (bool));
        // require(successApprove, "Failed to approve ERC20Handler");

        // Address.functionCallWithValue(
        //     bridgeAddress,
        //     abi.encodeWithSignature(
        //         "deposit(uint8,bytes32,bytes)",
        //         destChainID,
        //         erc20HandlerID,
        //         abi.encodePacked(
        //             abi.encode(transferTotal),
        //             abi.encode(uint256(20)),
        //             bridgeAddress
        //         )
        //     ),
        //     _fee,
        //     "Failed to deposit transfers on the bridge"
        // );

        // emit TokensSentToBridge();

        // delete transferCount;
        // delete transferTotal;
    // }

    function getCompany(uint16 _companyID)
        public
        view
        returns (
            string memory name,
            uint8 destChainID,
            address mirror,
            address localToken,
            address destToken
        )
    {
        Company storage c = companies[_companyID];
        return (c.name, c.destChainID, c.mirror, c.localToken, c.destToken);
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
