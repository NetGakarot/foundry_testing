// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

contract MyToken is Initializable,ERC20Upgradeable,OwnableUpgradeable {

    constructor() {_disableInitializers();}

    function initialize(string memory _name, string memory _symbol, address _owner) external initializer  {
        __ERC20_init(_name,_symbol);
        __Ownable_init(_owner);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}