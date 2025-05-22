// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract DiamondHands is Ownable {

    error InvalidAmount();
    error InsufficientBalance();
    error StillLocked();
    error FundsUnlocked();

    event Deposited(address indexed user, uint indexed time, uint amount);
    event Withdrawal(address indexed user, uint indexed time, uint amount);

    uint constant public minimumEth = 0.0001 ether;
    uint constant public lockedTime = 63072000 seconds;

    struct Details {
        uint balance;
        uint unlockTime;
    }
    mapping(address => Details) balanceOf;

    constructor() Ownable(msg.sender) {}

    function _deposit() internal {
        if(msg.value < minimumEth) revert InvalidAmount();
        Details storage details = balanceOf[msg.sender];
        uint oldAmount = details.balance;
        uint oldLockTime = details.unlockTime;
        details.unlockTime = (oldAmount * oldLockTime + msg.value * (block.timestamp + lockedTime)) / (oldAmount + msg.value);
        balanceOf[msg.sender].balance += msg.value;
        emit Deposited(msg.sender, block.timestamp, msg.value);
    }

    function deposit() public payable {_deposit();}
    fallback() external payable {_deposit();}
    receive() external payable {_deposit();}

    function withdraw() public payable {
        if(balanceOf[msg.sender].unlockTime > block.timestamp) revert StillLocked();
        if(balanceOf[msg.sender].balance == 0) revert  InsufficientBalance();
        uint amount = balanceOf[msg.sender].balance;
        balanceOf[msg.sender].balance = 0;
        (bool success, ) = payable(msg.sender).call{value:amount}("");
        require(success,"Failed!");
        emit Withdrawal(msg.sender, block.timestamp, amount);
    }

    function getRemainingTime() public view returns(uint) {
        if(balanceOf[msg.sender].unlockTime <= block.timestamp) revert FundsUnlocked();
        return balanceOf[msg.sender].unlockTime - block.timestamp;
    }

    function getBalance() public view returns(uint) {
        return balanceOf[msg.sender].balance;
    }

    function SelfDestruct() public onlyOwner {
        (bool success, ) = owner().call{value:address(this).balance}("");
        require(success,"Failed!");
        renounceOwnership();
    }
}
