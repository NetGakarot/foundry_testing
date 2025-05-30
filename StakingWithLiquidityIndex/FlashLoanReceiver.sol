// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendingPool {
    function flashLoan(
        address receiver,
        address asset,
        uint256 amount,
        bytes calldata params
    ) external;
}

contract FlashLoanReceiver {
    address public lendingPool;
    address public owner;

    constructor(address _lendingPool) {
        lendingPool = _lendingPool;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // LendingPool will call this function
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == lendingPool, "Unauthorized");

        // ✅ Custom logic here: arbitrage, liquidation, etc.
        // For demo: Just log + repay
        // You can decode params if needed: abi.decode(params, (uint256, address, ...))

        uint256 totalOwned = amount + fee;
        IERC20(asset).transfer(msg.sender, totalOwned);

        return true;
    }

    function startFlashLoan(address asset, uint256 amount, bytes calldata params) external onlyOwner {
        ILendingPool(lendingPool).flashLoan(address(this), asset, amount, params);
    }
}
