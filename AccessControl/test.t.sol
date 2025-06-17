// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/AccessControl.sol";

interface ILogic {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);


    function hasMyRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
    function getRoleAdmin(bytes32 role) external view  returns (bytes32);
    function pause() external;
    function unPause() external;
}

contract Testing is Test {

    MyContract token;
    address owner;
    address gakarot;
    address dummy;


    function setUp() external {
        owner = makeAddr("owner");
        gakarot = makeAddr("gakarot");
        dummy = makeAddr("dummy");
        vm.startPrank(owner);
        token = new MyContract(owner,"Gakarot","GAK$");  
        vm.stopPrank();
    }

    function testSetup() external view {

        assertEq(true,token.hasMyRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertEq(true,token.hasMyRole(token.MINTER_ROLE(), owner));
        assertEq(true,token.hasMyRole(token.BURNER_ROLE(), owner));
        assertEq(true,token.hasMyRole(token.PAUSER_ROLE(), owner));
    }

    function testMintBurn() external {
        vm.startPrank(owner);
        token.mint(gakarot, 10e18);
        assertEq(token.balanceOf(gakarot), 10e18);
        token.burn(gakarot, 5e18);
        assertEq(token.balanceOf(gakarot), 5e18);
        vm.stopPrank();
        vm.expectRevert();
        token.mint(gakarot, 10e18);
        vm.expectRevert();
        token.burn(gakarot, 10e18);
    }

    function testPaused() external {
        vm.startPrank(owner);
        token.pause();
        vm.expectRevert();
        token.mint(gakarot, 10e18);
        token.unPause();
        token.mint(gakarot, 10e18);
        assertEq(token.balanceOf(gakarot), 10e18);
    }

    function testGrantingRevokingRole() external {
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), gakarot);
        assertEq(true, token.hasMyRole(token.MINTER_ROLE(), gakarot));
        vm.stopPrank();

        vm.startPrank(gakarot);
        token.mint(dummy,10e18);
        assertEq(token.balanceOf(dummy), 10e18);
        vm.expectRevert();
        token.burn(dummy, 10e18);
        vm.stopPrank();

        vm.startPrank(owner);
        token.revokeRole(token.MINTER_ROLE(), gakarot);
        vm.stopPrank();
        
        vm.startPrank(gakarot);
        vm.expectRevert();
        token.mint(dummy,10e18);
        vm.stopPrank();
    }
}