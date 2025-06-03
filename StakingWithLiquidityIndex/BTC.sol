// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract _BTC is ERC20, Ownable {


    constructor() ERC20("BTC","$BTC") Ownable(msg.sender) {
        _mint(msg.sender, 100000);
    }

    function mint(address account, uint256 _value) external onlyOwner {
        _mint(account, _value);
    }

    function burn(address account, uint256 _value) external onlyOwner {
        _burn(account, _value);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

