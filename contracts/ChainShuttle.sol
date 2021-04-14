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
        mapping (address => uint256) sendersAmounts;
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
    event ShuttleDeparture(
        uint16 indexed companyID,
        uint16 indexed shuttleID,
        uint256 totalAmount
    );

    modifier onlyBridgeSetUp {
        require(bridgeAddress != address(0), "Bridge address is not configured");
        require(erc20HandlerAddress != address(0), "Bridge address is not configured");
        require(genericHandlerAddress != address(0), "Bridge address is not configured");
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
        require(Address.isContract(_genericHandler), "GenericHandler address must be a contract");
        require(_erc20ResourceID != 0, "ERC20Handler ResourceID cannot be 0");
        require(_shuttleResourceID != 0, "GenericHandler ResourceID cannot be 0");
        bridgeAddress = _bridge;
        erc20HandlerAddress = _erc20Handler;
        erc20ResourceID = _erc20ResourceID;
        genericHandlerAddress = _genericHandler;
        shuttleResourceID = _shuttleResourceID;
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
        require(msg.value == bridgeFee*2 / s.capacity, "Value has to be enough to pay the bridge");

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
        s.totalAmount += _amount;
        s.numDeposits++;

        emit DepositRegistered(s.companyID, _shuttleID, msg.sender, _to, _amount);

        if (s.numDeposits == s.capacity) {
            bool successApprove = abi.decode(Address.functionCall(
                c.localToken,
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

            // Address.functionCallWithValue(
            //     bridgeAddress,
            //     abi.encodeWithSignature(
            //         "deposit(uint8,bytes32,bytes)",
            //         c.destChainID,
            //         shuttleResourceID,
            //         generateShuttleData(_shuttleID)
            //     ),
            //     bridgeFee,
            //     "Failed to send shuttle data through the bridge"
            // );

            emit ShuttleDeparture(s.companyID, _shuttleID, s.totalAmount);
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
            // lenMetadata = depositer + capacity + capacity * 2 * 
            abi.encode(32 + s.capacity*2*32),
            // depositer lenght + depositer address
            // abi.encode(20),
            // abi.encode(msg.sender),
            abi.encode(s.capacity),
            recipients,
            amounts
        );
    }

    function offloadShuttle(bytes calldata _data)
        public
        pure
        returns (
            uint256 numDeposits,
            address[] memory recipients,
            uint256[] memory amounts
        )
    {
        // Skip depositer address
        numDeposits = abi.decode(_data, (uint256));
        recipients = new address[](numDeposits);
        amounts = new uint256[](numDeposits);
        // Skip depositer address and numDeposits
        uint256 dOffset = 0;
        uint256 aOffset = 0 + numDeposits*32;

        for (uint d=0; d < numDeposits; d++) {
            recipients[d] = abi.decode(_data[dOffset+d*32:dOffset+(d+1)*32], (address));
            amounts[d] = abi.decode(_data[aOffset+(d*32):aOffset+(d+1)*32], (uint256));
        }
    }

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
