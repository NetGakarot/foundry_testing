// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error InvalidPrice();
error InvalidAddress();

contract MyToken is ERC20, Ownable {

    event Minted(address indexed _account, uint256 _value);
    event Burned(address indexed _account, uint256 _value);
    event Transfered(address indexed _to, uint256 _value);

    constructor(address _owner) ERC20("GAKAROT","GAK$") Ownable(_owner) {}

    function transfer(address to, uint256 value) public override returns (bool) {
        bool success = super.transfer(to, value);
        emit Transfered(to, value);
        return success;
    }

    function mint(address account, uint256 value) external {
        _mint(account, value);
        emit Minted(account, value);
    }

    function burn(address account, uint256 value) external {
        _burn(account, value);
        emit Burned(account, value);
    }
}