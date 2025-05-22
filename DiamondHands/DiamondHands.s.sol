// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "forge-std/Script.sol";
import "../src/DiamondHands.sol";

contract DeployScript is Script {
    function run() external {

        vm.startBroadcast();

        // Deploy contract
        DiamondHands dh = new DiamondHands();

        vm.stopBroadcast();

        console.log("Deployed at:", address(dh));
    }
}

