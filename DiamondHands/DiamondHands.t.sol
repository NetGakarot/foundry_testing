// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DiamondHands.sol";

contract Interaction is Test {

    DiamondHands public target;

    function setUp() public {
        target = new DiamondHands();
        assertEq(target.owner(), address(this));
    }

    function testDeposit() public {
        address user1 = address(1990);
        vm.deal(user1, 100 ether);
        vm.startPrank(user1);
        target.deposit{value:1 ether}();
        assertEq(target.getBalance(), 1 ether);
        assertEq(target.getRemainingTime(), 63072000 seconds);
        (bool success, ) = address(target).call{value:1 ether}("");
        require(success, "Failed");
        assertEq(target.getBalance(), 2 ether);
        vm.warp(block.timestamp + 63072001 seconds);
        target.withdraw();
        assertEq(target.getBalance(), 0);
        vm.expectRevert();
        target.SelfDestruct();
        vm.stopPrank();
        assertEq(address(target).balance, 0);
    }

    function testFuzz(uint256 amount) public {
        vm.assume(amount >= 0.0001 ether && amount <= 99 ether );
        uint boundedValue = bound(amount, 1 ether, 97 ether);
        address user1 = address(1990);
        vm.deal(user1, 100 ether);
        vm.startPrank(user1);
        target.deposit{value:boundedValue}();
        assertEq(target.getBalance(), boundedValue);
        vm.stopPrank();
    }

    function invariant_balanceAlwaysPositive() public {
        address user1 = address(1990);
        vm.deal(user1, 100 ether);
        vm.startPrank(user1);
        target.deposit{value: 1 ether}();
        vm.stopPrank();
        assertGe(target.getBalance(), 0);
    }
}

