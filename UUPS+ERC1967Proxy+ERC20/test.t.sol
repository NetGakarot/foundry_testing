// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Logic.sol";
import "../src/Proxy.sol";

interface ILogic {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function initialize(string memory, string memory) external;
    function owner() external view returns (address);
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    
}


contract Testing is Test {

    MyToken _logic;
    MyProxy _proxy;
    address ironman;
    address gakarot;
    address dummy;
    ILogic logic;

    function setUp() external {
        _logic = new MyToken();
        _proxy = new MyProxy(address(_logic),"GAKAROT","GAK$",address(this));
        logic = ILogic(address(_proxy));
        ironman = makeAddr("ironman");
        gakarot = makeAddr("gakarot");
        dummy = makeAddr("dummy");
        logic.mint(ironman, 100e18);
        logic.mint(gakarot, 100e18);
    }

    function testSetup() external {
        vm.expectRevert();
        logic.initialize("Dummy", "DUM$");
        assertEq(logic.owner(), address(this));
    }

    function testUpgrade() external {
        MyToken mocked = new MyToken();
        logic.upgradeToAndCall(address(mocked), "");
        ILogic mock = ILogic(address(mocked));
        assertEq(mock.totalSupply(), 0);
        vm.expectRevert();
        mock.initialize("anything", "anything");
    }

     function testTransfer() external {
        vm.prank(ironman);
        logic.transfer(gakarot,10e18);
        assertEq(logic.balanceOf(gakarot), 110e18);
        assertEq(logic.balanceOf(ironman), 90e18);
    }

     function testMintBurn() external {
        logic.mint(dummy, 1000e18);
        assertEq(logic.balanceOf(dummy), 1000e18);
        logic.burn(dummy, 1000e18);
        assertEq(logic.balanceOf(dummy), 0);
    }

    function testTransferApproveTransferFrom() external {
        vm.prank(ironman);
        logic.approve(gakarot, 50e18);
        vm.startPrank(gakarot);
        logic.transferFrom(ironman, dummy, 20e18);
        assertEq(logic.balanceOf(ironman), 80e18);
        logic.transferFrom(ironman, dummy, 30e18);
        assertEq(logic.balanceOf(ironman), 50e18);
        assertEq(logic.allowance(ironman,gakarot),0);
        vm.expectRevert();
        logic.transferFrom(ironman, dummy, 20e18);
        vm.stopPrank();
    }

    function testFuzz(uint256 _amount1,uint256 _amount2) external {
        uint256 amount1 = bound(_amount1, 1e9, 5e18);
        uint256 amount2 = bound(_amount2, 1e9, 5e18);
        vm.startPrank(ironman);
        logic.approve(gakarot, amount1);
        assertEq(logic.allowance(ironman,gakarot),amount1);
        logic.transfer(dummy, amount2);
        vm.stopPrank();
        vm.startPrank(gakarot);
        logic.transferFrom(ironman, dummy, amount1);
        assertEq(logic.allowance(ironman,gakarot),0);
        logic.transfer(dummy, amount2);
        vm.stopPrank();
    }

    function invariant_TransferAmountShouldAlwaysBePositive() external {
        vm.startPrank(ironman);
        bool success = logic.transfer(dummy, 1e18);
        assertTrue(success);
        vm.stopPrank();
    }
}