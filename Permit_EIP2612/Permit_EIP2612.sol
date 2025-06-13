// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/** @author - Fee setting guide:
                        -Set fees in basis points (bps), where 1% = 100 bps.
                        -Example:
                        -For 0.25% fee, set fees = 25
                        -For 0.50% fee, set fees = 50
                        -For 1% fee, set fees = 100 and so on.
                        -This approach ensures accurate fee calculation without decimals.
                        */

                        
contract MyToken is ERC20, ERC20Permit, Ownable {
    address treasury;
    uint256 fees;       

    constructor(string memory _name, string memory _symbol, address _treasury, uint256 _fees ) ERC20(_name,_symbol) Ownable(msg.sender) ERC20Permit(_name) {
        treasury = _treasury;
        fees = _fees;
    }
    
    function mint(address account, uint256 value) external onlyOwner {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyOwner {
        _burn(account, value);
    }

      function setTreasury(address _treasury) external onlyOwner {
        require(treasury != address(0), "Treasury not set");
        treasury = _treasury;
    }

      function setFees(uint256 _fees) external onlyOwner {
        fees = _fees; 
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address from = _msgSender();
        _feeTransfer(from, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(from, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _approve(from, _msgSender(), currentAllowance - amount);
        _feeTransfer(from, to, amount);
        return true;
    }

    function _feeTransfer(address from, address to, uint256 amount) internal {
        if (fees == 0 || from == treasury || to == treasury) {
            _transfer(from, to, amount);
        } else {
            uint256 feeAmount = (amount * fees) / 10000;
            uint256 netAmount = amount - feeAmount;
            _transfer(from, to, netAmount);
            _transfer(from, treasury, feeAmount);
        }
    }
}
