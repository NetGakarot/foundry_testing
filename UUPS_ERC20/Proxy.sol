// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Proxy {
    constructor(address _logic) payable {
        _setImplementation(_logic);
    }

    fallback() external {
        _delegate(_implementation());
    }


    function _implementation() public view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    // EIP-1967 implementation storage slot:
    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant _IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
}
