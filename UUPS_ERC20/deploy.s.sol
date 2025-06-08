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
/* 
---> Forge command for deploying: Run this in CLI (For testnet)
$env:ALCHEMY_API_URL="https://eth-sepolia.g.alchemy.com/v2/YourAlchemyKey"
$env:PRIVATE_KEY="YourWalletPrivateKey"
forge script script/DeployLogic.s.sol:DeployLogic --rpc-url $env:ALCHEMY_API_URL --private-key $env:PRIVATE_KEY --broadcast --chain-id 11155111
*/
