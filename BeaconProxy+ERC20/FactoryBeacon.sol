// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract Factory {

    address public beacon;
    address[] public allVaults;
    constructor(address _logic, address _owner) {
        UpgradeableBeacon _beacon = new UpgradeableBeacon(_logic,_owner);
        beacon = address(_beacon);
    }

      function createProxy(string memory _name, string memory _symbol, address _owner) external returns (address) {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("initialize(string,string,address)")),
            _name, _symbol, _owner
        );

        BeaconProxy proxy = new BeaconProxy(beacon, data);
        allVaults.push(address(proxy));
        return address(proxy);
    }
}