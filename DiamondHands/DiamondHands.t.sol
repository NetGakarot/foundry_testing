// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DiamondHands.sol";
import "../src/Dummy.sol";

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

    function testWithdrawWithoutDeposit() public {
        vm.expectRevert(DiamondHands.InsufficientBalance.selector);
        target.withdraw();
    }

    function testInvalidDeposit() public {
        address user1 = address(1001);
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        vm.expectRevert(DiamondHands.InvalidAmount.selector);
        target.deposit{value: 0.00001 ether}();
        vm.stopPrank();
    }

    function testGetRemainingTimeAfterUnlock() public {
        address user1 = address(2000);
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        target.deposit{value: 1 ether}();
        vm.warp(block.timestamp + 63072001);
        vm.expectRevert(DiamondHands.FundsUnlocked.selector);
        target.getRemainingTime();
        vm.stopPrank();
    }

    function testSelfDestructByOwner() public {
        address owner = address(this);
        vm.deal(address(target), 1 ether);
        vm.startPrank(owner); // add balance to contract
        target.SelfDestruct();
        assertEq(address(target).balance, 0);
        assertEq(address(this).balance, 79228162515264337593543950335 wei);
        vm.stopPrank();
    }

    function testFuzzMultipleDeposits(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1 ether, 10 ether);
        amount2 = bound(amount2, 1 ether, 10 ether);

        address user = address(999);
        vm.deal(user, 100 ether);
        vm.startPrank(user);

        target.deposit{value: amount1}();
        uint t1 = target.getRemainingTime();
        assertGt(t1, 0);

        vm.warp(block.timestamp + 10); // small warp to change second deposit time
        target.deposit{value: amount2}();
        uint t2 = target.getRemainingTime();

        assertGt(t2, 0);
        vm.stopPrank();
    }

    function testFallback() public {
        address user1 = address(2000);
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        (bool success, ) = address(target).call{value:1 ether}(abi.encodeWithSignature("non-existent()"));
        require(success,"Failed");
        assertEq(address(target).balance, 1 ether);
        vm.stopPrank();
    }

    function testWithdrawFailures() public {
        address user1 = address(2000);
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        target.deposit{value:1 ether}();
        vm.expectRevert();
        target.withdraw();
        vm.stopPrank();
    }

    function testWithdrawFailures2() public {
        Dummy dummy = new Dummy();
        vm.deal(address(dummy), 1 ether);
        vm.startPrank(address(dummy));
        target.deposit{value:1 ether}();
        vm.warp(block.timestamp + 63072001);
        vm.expectRevert();
        target.withdraw();
        vm.stopPrank();
    }

    function testSelfDestructTransferFailure() public {
        Dummy dummy = new Dummy();
        vm.deal(address(target), 10 ether);
        target.transferOwnership(address(dummy));
        vm.startPrank(address(dummy));
        vm.expectRevert();
        target.SelfDestruct();
        vm.stopPrank();
    }

    receive() external payable {}
}

