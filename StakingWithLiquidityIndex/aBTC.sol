// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract aBTC is ERC20, Ownable {

    error InvalidAddress();
    error NotAuthorized();

    address public stakingContract;

    constructor(address _staking) ERC20("aBTC","$aBTC") Ownable(msg.sender) {
        stakingContract = _staking;
    }

    modifier onlyStaking() {
        if(msg.sender != stakingContract) revert NotAuthorized();
        _;
    }

    function mint(address account, uint256 _value) external onlyStaking {
        _mint(account, _value);
    }

    function burn(address account, uint256 _value) external onlyStaking {
        _burn(account, _value);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function setStakingContract(address _newStaking) external onlyOwner {
        if(_newStaking == address(0)) revert InvalidAddress();
        stakingContract = _newStaking;
    }
}


