// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyContract is AccessControl, ERC20 {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bool paused;
    
    modifier whenNotPaused() {
        require(!paused,"Contract is paused");
        _;
    }

    constructor(address admin, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function mint(address _account, uint256 _value) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(_account, _value);
    }
    function burn(address _account, uint256 _value) external onlyRole(BURNER_ROLE) whenNotPaused {
        _burn(_account, _value);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
    } 
    function unPause() external onlyRole(PAUSER_ROLE) {
        paused = false;
    }

    function hasMyRole(bytes32 role, address account) external view returns (bool) {
        return hasRole(role, account);
}

}