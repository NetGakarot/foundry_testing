// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error InvalidPrice();
error InvalidAddress();

contract MyToken is ERC20, Ownable {

    constructor(address _owner) ERC20("GAKAROT","GAK$") Ownable(_owner) {}

    function mint(address account, uint256 value) external {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external {
        _burn(account, value);
    }
}