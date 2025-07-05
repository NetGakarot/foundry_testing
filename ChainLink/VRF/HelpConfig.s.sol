// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


contract HelperConfig {

    struct NetworkConfig {
        uint256 enteranceFees;
        uint256 interval;
        uint256 subscriptionId;
    }

    NetworkConfig public networkConfig;

    constructor() {
        if(block.chainid == 31337) {
            networkConfig = getAnvilConfig();
        } else if(block.chainid == 11155111) {
            networkConfig = getSepoliaConfig();
        } else {
            revert ("Network not found");
        }
    }

    function getAnvilConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig ({
            enteranceFees: 10000000000,
            interval: 300,
            subscriptionId:1
        });
    }
    function getSepoliaConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig ({
            enteranceFees: 10000000000,
            interval: 300,
            subscriptionId:16473829467382947382987438297467374386473892
        });
    }
}