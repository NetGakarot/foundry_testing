// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MyProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        string memory _name,
        string memory _symbol,
        address owner
    )
        TransparentUpgradeableProxy(
            _logic,
            owner, // initial owner
            abi.encodeWithSignature("initialize(string,string,address)", _name, _symbol, owner)
        )
    {}

    
}
