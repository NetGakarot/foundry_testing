// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyProxy is ERC1967Proxy {
    constructor(
        address _logicAddress,
        string memory _name,
        string memory _symbol,
        address owner
    )
        ERC1967Proxy(
            _logicAddress,
            abi.encodeWithSelector(bytes4(keccak256("initialize(string,string)")), _name, _symbol,owner)
        )
    {}
}
