// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MerkleAirdrop, IERC20} from "../src/MerkleAirdrop.sol";
import {Script} from "forge-std/Script.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {console} from "forge-std/console.sol";

contract DeployMerkleAirdrop is Script {
    uint256 public constant AMOUNT_TO_TRANSFER = 4 * (25 * 1e18);

    function deployMerkleAirdrop() public returns (MerkleAirdrop, BagelToken) {
        vm.startBroadcast();
        BagelToken token = new BagelToken();
        MerkleAirdrop airdrop = new MerkleAirdrop(IERC20(token));
        token.mint(token.owner(), AMOUNT_TO_TRANSFER);
        IERC20(token).transfer(address(airdrop), AMOUNT_TO_TRANSFER);
        vm.stopBroadcast();
        return (airdrop, token);
    }

    function run() external returns (MerkleAirdrop, BagelToken) {
        return deployMerkleAirdrop();
    }
}
