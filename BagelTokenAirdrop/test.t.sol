// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract Testing is Test {
    BagelToken token;
    MerkleAirdrop airdrop;

    uint256 amountToClaim = 25000000000000000000;

    bytes32 proofOne = 0x28846fc58cd99b8fc6c9b996e5ab989612375d51615b64e80526b6909930bb66;
    bytes32 proofTwo = 0x68028bf0c2b4cd46ba2aeecf291ec36bf8efafe02bbc1887708062aa5e5ebb87;
    bytes32[] proof = [proofOne, proofTwo];

    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() external {
        (airdrop, token) = new DeployMerkleAirdrop().run();
    }

    function testUsersCanClaim() public {
        uint256 startingBalance = token.balanceOf(user1);

        uint256 privateKey = uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        bytes32 digest = airdrop.getMessageHash(user1, amountToClaim);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.startPrank(user1);
        airdrop.claim(user1, amountToClaim, proof, v, r, s);
        uint256 endingBalance = token.balanceOf(user1);
        console.log("Ending balance:", endingBalance);
        assertEq(endingBalance - startingBalance, amountToClaim);
        vm.stopPrank();
    }
}

/**
 * Format:
 *     User: address
 *     Amount: amount
 *     Leaf: Double hash of account + amount
 *     Proof: [Hash of user2 details, H34]
 *
 * 🔗 Merkle Root: 0xbbaee090ecea8ec3e5b792ddf25166d86a42439b02f01c462e4eb5b78df3357c
 *
 * 📤 User: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
 *    Amount: 25000000000000000000
 *    Leaf: 0x16440518c56abeb829b31fe7f6f64b0ffc6e3b5ab8cf006e3b0bb439388da388
 *    Proof: ["0x28846fc58cd99b8fc6c9b996e5ab989612375d51615b64e80526b6909930bb66", "0x68028bf0c2b4cd46ba2aeecf291ec36bf8efafe02bbc1887708062aa5e5ebb87"]
 *
 * 📤 User: 0xA5e4C6932f1FFee559d6f28e54738B18155e95f9
 *    Amount: 25000000000000000000
 *    Leaf: 0x28846fc58cd99b8fc6c9b996e5ab989612375d51615b64e80526b6909930bb66
 *    Proof: ["0x16440518c56abeb829b31fe7f6f64b0ffc6e3b5ab8cf006e3b0bb439388da388", "0x68028bf0c2b4cd46ba2aeecf291ec36bf8efafe02bbc1887708062aa5e5ebb87"]
 *
 * 📤 User: 0x8BDB2FAB7891acCCC2F4B9EF716E0ae45D1f9b26
 *    Amount: 25000000000000000000
 *    Leaf: 0x88fa27112662e3f004a2b3b2ce0c7e4bc4313754de700bd0ee325a6a858f4f03
 *    Proof: ["0xf9b783a64aa02a29c1841318faa7afd6c0fd4661d3c2e8ebf06bd8c3c08cac9c", "0x88ebb58f58d605aa730ff01c259c03f24968d3dd46ca8aef1c4893c85393be49"]
 *
 * 📤 User: 0x222B8c7b435681C886928B9210e26DebDaC3a223
 *    Amount: 25000000000000000000
 *    Leaf: 0xf9b783a64aa02a29c1841318faa7afd6c0fd4661d3c2e8ebf06bd8c3c08cac9c
 *    Proof: ["0x88fa27112662e3f004a2b3b2ce0c7e4bc4313754de700bd0ee325a6a858f4f03", "0x88ebb58f58d605aa730ff01c259c03f24968d3dd46ca8aef1c4893c85393be49"]
 */
