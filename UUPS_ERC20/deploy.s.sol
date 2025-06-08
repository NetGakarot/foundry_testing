// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Logic.sol";
import "../src/Proxy.sol";

interface ILogic {
    function initialize(string memory name, string memory symbol) external;
}

contract DeployLogic is Script {
    function run() external {
        vm.startBroadcast();

        MyToken logic = new MyToken();
        Proxy proxy = new Proxy(address(logic));
        ILogic(address(proxy)).initialize("Gakarot", "GAK$");

        vm.stopBroadcast();
    }
}

