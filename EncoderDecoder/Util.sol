// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract Util {

    function encodeTransfer(address to, uint256 amount) external pure returns(bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), to,amount);
    }
    function encodeApprove(address spender, uint256 amount) external pure returns(bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("approve(address,uint256)")), spender,amount);
    }
    function encodeTransferFrom(address from,address to, uint256 amount) external pure returns(bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("transfer(address,address,uint256)")), from, to,amount);
    }

    function decodeTransfer(bytes calldata data) external pure returns(address to, uint256 value) {
        (to, value) = abi.decode(data[4:],(address,uint256));
        return (to, value);
    }
    function decodeApprove(bytes calldata data) external pure returns(address from, uint256 value) {
        (from, value) = abi.decode(data[4:],(address,uint256));
        return (from, value);
    }
    function decodeTransferFrom(bytes calldata data) external pure returns(address from,address to, uint256 value) {
        (from, to, value) = abi.decode(data[4:],(address,address,uint256));
        return (from, to, value);
    }

    function getSelector(bytes calldata data) external pure returns (bytes4) {
        return bytes4(data);
    }

    function getFunctionName(bytes calldata data) external pure returns (string memory) {
        bytes4 selector = bytes4(data);
        if (selector == bytes4(keccak256("transfer(address,uint256)"))) return "transfer";
        if (selector == bytes4(keccak256("approve(address,uint256)"))) return "approve";
        if (selector == bytes4(keccak256("transferFrom(address,address,uint256)"))) return "transferFrom";
        return "unknown";
    }
}