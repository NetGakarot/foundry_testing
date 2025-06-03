// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "../src/aETH.sol";
import "../src/aBTC.sol";
import "../src/ETH.sol";
import "../src/BTC.sol";

contract Testing is Test {

    Staking public stake;
    aETH public aeth;
    aBTC public abtc;
    _ETH public eth;
    _BTC public btc;
    address shubham = makeAddr("shubham");
    address gakarot = makeAddr("gakarot");
    address gaka = makeAddr("gaka");
    address shubu = makeAddr("shubu");

    function setUp() public {
        stake = new Staking(7,2);
        aeth = new aETH(address(stake));
        abtc = new aBTC(address(stake));
        eth = new _ETH();
        btc = new _BTC();
        stake.addAllowedToken(address(eth), address(aeth));
        stake.addAllowedToken(address(btc), address(abtc));
        eth.mint(eth.owner(), 10000000000e18);
        eth.transfer(address(eth), 1000e18);
        eth.transfer(address(stake), 1000e18);
        btc.mint(btc.owner(), 1000000e18);
        btc.transfer(address(btc), 1000e18);
        btc.transfer(address(stake), 1000e18);
        eth.transfer(shubham, 1000e18);
        eth.transfer(gakarot, 1000e18);
        btc.transfer(gaka, 1000e18);
        btc.transfer(shubu, 1000e18);
    }

    function testSetup() public view {
        assertEq(stake.owner(), address(this));
        assertEq(aeth.owner(), address(this));
        assertEq(abtc.owner(), address(this));
        assertEq(eth.owner(), address(this));
        assertEq(btc.owner(), address(this));
        assertEq(aeth.stakingContract(), address(stake));
        assertEq(abtc.stakingContract(), address(stake));
        assertGt(eth.balanceOf(address(this)),900000e18);
        assertEq(eth.balanceOf(address(eth)),1000e18);
        assertGt(btc.balanceOf(address(this)),900000e18);
        assertEq(btc.balanceOf(address(btc)),1000e18);
    }

    function testDeposit() public {
        vm.startPrank(shubham);
        eth.approve(address(stake), 5e18);
        stake.deposit(address(eth), 5e18);
        vm.warp(block.timestamp + 1000 days);
        //assertGt(stake.balanceOf(shubham, address(eth)),5e18);
        uint256 x = stake.balanceOf(shubham, address(eth));
        console.log("balance of gakarot:",x);
        vm.stopPrank();
        vm.startPrank(gakarot);
        eth.approve(address(stake), 5e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        assertGt(stake.balanceOf(gakarot, address(eth)),5e18);
        vm.stopPrank();
        vm.startPrank(shubham);
        assertGt(stake.balanceOf(shubham, address(eth)),5e18);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(gakarot);
        eth.approve(address(stake), 5e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 10 days);
        assertGt(stake.balanceOf(gakarot, address(eth)),5e18);
        uint256 x = stake.balanceOf(gakarot,address(eth));
        console.log("Balance of gakarot:",x);
        stake.withdraw(address(eth), 5.000005e18);
        uint256 y = stake.balanceOf(gakarot,address(eth));
        console.log("Balance of gakarot:",y);
        vm.stopPrank();
    }

    function testFuzz(uint256 _amount1, uint256 _amount2) public {
        uint256 amount1 = bound(_amount1,1e9,20e18);
        uint256 amount2 = bound(_amount2,1e9,20e18);
        vm.startPrank(shubham);
        eth.approve(address(stake), 5000e18);
        stake.deposit(address(eth),amount1);
        vm.warp(block.timestamp + 10 days);
        stake.deposit(address(eth),amount2);
        assertGt(stake.balanceOf(shubham, address(eth)), 0);
        uint256 x = stake.balanceOf(shubham, address(eth));
        console.log("Balance of shubham is:",x);
        vm.stopPrank();
    }

    function invariant_InterestAlwaysGreaterThanZero() public {
        vm.startPrank(shubham);
        eth.approve(address(stake), 50e18);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 100 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 100 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 100 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 100 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 100 days);
        stake.deposit(address(eth), 1e18);
        vm.warp(block.timestamp + 100 days);
        vm.stopPrank();
        uint256 staked = stake.balanceOf(shubham, address(eth));
        console.log("Balance of shubham:",staked);
        if(staked > 0) {
            assertGt(stake.earnedInterest(shubham, address(eth)), 0);
        }
    }
}