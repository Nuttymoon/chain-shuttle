// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FOOToken is ERC20 {
    constructor() public ERC20("Foo", "FOO") {
        _mint(msg.sender, 1000000000000000000000);
    }
}
