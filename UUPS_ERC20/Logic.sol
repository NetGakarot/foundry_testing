// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelinu/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelinu/contracts/proxy/utils/Initializable.sol";
import "@openzeppelinu/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";


contract MyToken is Initializable,ERC20Upgradeable,OwnableUpgradeable, UUPSUpgradeable {

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol) external initializer {
    __ERC20_init(_name, _symbol);
    __Ownable_init(msg.sender);
    }

    function mint(address account, uint256 value) external onlyOwner {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyOwner {
        _burn(account, value);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner onlyProxy {}
}


