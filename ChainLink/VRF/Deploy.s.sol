// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/Raffle.sol";
import {HelperConfig} from "./HelpConfig.s.sol";

contract Deploy is Script {

    function run() external returns(Raffle) {
        HelperConfig config = new HelperConfig();
        (uint256 enetranceFees, uint256 interval, uint256 subId) = config.networkConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(enetranceFees,interval,subId);
        console.log("Raffle is deployed at:", address(raffle));
        vm.stopBroadcast();
        return raffle;
    }

}