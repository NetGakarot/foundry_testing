// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/Permit_EIP2612.sol";
import "forge-std/Test.sol";

contract Testing is Test {

    MyToken token;
    address owner;
    uint256 ownerPk;
    address spender;


    function setUp() external {
        ownerPk = 0xA11CE; // mock private key
        owner = vm.addr(ownerPk); // address generated from key

        spender = address(0xBEEF);

        token = new MyToken("GAKAROT", "GAK$");

        token.mint(owner, 1_000 ether);
    }

    function testPermit() public {
        uint256 value = 100 ether;
        uint256 nonce = token.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        // Sign digest using private key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        // Spender calls permit with signature from owner
        vm.prank(spender);
        token.permit(owner, spender, value, deadline, v, r, s);

        // Check allowance
        assertEq(token.allowance(owner, spender), value);
    }
}