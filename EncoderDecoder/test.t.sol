// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Util.sol";

interface IUtil {
    function encodeTransfer(address to, uint256 amount) external pure returns(bytes memory);
    function encodeApprove(address spender, uint256 amount) external pure returns(bytes memory);
    function encodeTransferFrom(address from,address to, uint256 amount) external pure returns(bytes memory);
    function decodeTransfer(bytes calldata data) external pure returns(address to, uint256 value);
    function decodeApprove(bytes calldata data) external pure returns(address from, uint256 value);
    function decodeTransferFrom(bytes calldata data) external pure returns(address from,address to, uint256 value);
}

contract Testing is Test {

    Util util;
    address shubham;
    address gakarot;

    function setUp() external {
        util = new Util();
        shubham = makeAddr("shubham");
        gakarot = makeAddr("gakarot");
    }

    function testEncodeDecodeTransfer() external view {
        bytes memory encoded = util.encodeTransfer(shubham, 1e18);
        (address to, uint256 amount) = util.decodeTransfer(encoded);
        console.log("to = ",to,"amount = ",amount);
        assertEq(to, address(shubham));
        assertEq(amount, 1e18);
    }
    function testEncodeDecodeApprove() external view {
        bytes memory encoded = util.encodeApprove(shubham, 1e18);
        (address from, uint256 amount) = util.decodeApprove(encoded);
        console.log("from = ",from,"amount = ",amount);
        assertEq(from, address(shubham));
        assertEq(amount, 1e18);
    }

    function testEncodeDecodeTransferFrom() external view {
        bytes memory encoded = util.encodeTransferFrom(shubham, gakarot, 1e18);
        (address from, address to, uint256 amount) = util.decodeTransferFrom(encoded);
        console.log("from = ",from);
        console.log("to = ",to);
        console.log("amount = ",amount);
        assertEq(from, address(shubham));
        assertEq(to, address(gakarot));
        assertEq(amount, 1e18);
    }

    function testGetSelector() external view {
        bytes memory encoded = util.encodeTransfer(shubham, 1e18);
        bytes4 selector = util.getSelector(encoded);
        assertEq(selector, bytes4(keccak256("transfer(address,uint256)")));
    }

    function testGetFunctionName() external view {
        bytes memory data = util.encodeTransfer(shubham, 1e18);
        assertEq("transfer",util.getFunctionName(data));
    }
}