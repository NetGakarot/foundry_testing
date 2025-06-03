// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IaToken {
    function mint(address to, uint256 amount) external;
    function burn(address to, uint256 amount) external;
}

contract Staking is Ownable {
    error InvalidAmount();
    error InvalidAsset();
    error AlreadyAllowed();

    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event ReserveFactorUpdated(uint256 old, uint256 _new);
    event APYUpdated(uint256 old, uint256 _new);

    uint256 reserveFactor;
    uint256 apy;

    mapping(address => bool) public allowedToken;
    mapping(address => address) public aToken;
    mapping(address => uint256) public liquidityIndex; // asset => index
    mapping(address => uint256) public lastUpdate; // asset => timestamp

    mapping(address => mapping(address => uint256)) public scaledBalance; // user => asset => scaled amt
    mapping(address => mapping(address => uint256)) public userDepositIndex; // user => asset => last index
    mapping(address => mapping(address => uint256)) public userPrincipal; // user => asset => principal
    mapping(address => uint256) totalPool;

    uint256 public constant RAY = 1e27;
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    constructor(uint256 _apy, uint256 _reserveFactor) Ownable(msg.sender) {
        apy = _apy;
        reserveFactor = _reserveFactor;
    }

    function addAllowedToken(address asset, address _aToken) external onlyOwner {
        if (allowedToken[asset]) revert AlreadyAllowed();
        allowedToken[asset] = true;
        liquidityIndex[asset] = RAY;
        lastUpdate[asset] = block.timestamp;
        aToken[asset] = _aToken;
    }

    function removeToken(address asset) external onlyOwner {
        allowedToken[asset] = false;
        aToken[asset] = address(0);
    }

    function setReserveFactor(uint256 _factor) external onlyOwner {
        uint256 oldReserveFactor = reserveFactor;
        reserveFactor = (RAY * _factor) / 100;
        emit ReserveFactorUpdated(oldReserveFactor, reserveFactor);
    }

    function setAPY(uint256 rate) external onlyOwner {
        require(rate <= 20, "APY too high");
        uint256 oldAPY = apy;
        apy = rate;
        emit APYUpdated(oldAPY, apy);
    }

    function deposit(address asset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        if (!allowedToken[asset]) revert InvalidAsset();

        _updateLiquidityIndex(asset);

        uint256 index = liquidityIndex[asset];
        uint256 scaledAmount = (amount * RAY) / index;
        scaledBalance[msg.sender][asset] += scaledAmount;
        userDepositIndex[msg.sender][asset] = index;

        userPrincipal[msg.sender][asset] += amount;
        totalPool[asset] += amount;

        IaToken(aToken[asset]).mint(msg.sender, scaledAmount);
        require(IERC20(asset).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external {
        if (!allowedToken[asset]) revert InvalidAsset();

        _updateLiquidityIndex(asset);

        uint256 index = liquidityIndex[asset];
        uint256 userScaled = scaledBalance[msg.sender][asset];
        uint256 actualBalance = (userScaled * index) / RAY;

        if (amount == 0 || amount > actualBalance) revert InvalidAmount();

        uint256 totalInterest = earnedInterest(msg.sender, asset);
        uint256 proportionalInterest = (totalInterest * amount) / actualBalance;

        uint256 reserveCut = (proportionalInterest * reserveFactor) / RAY;
        uint256 userAmount = amount - reserveCut;

        // Update scaled balance
        scaledBalance[msg.sender][asset] = ((actualBalance - amount) * RAY) / index;

        // Burn aToken
        uint256 scaledToBurn = (amount * RAY + index / 2) / index;
        IaToken(aToken[asset]).burn(msg.sender, scaledToBurn);

        // Subtract only principal from pool & principal mapping
        uint256 principalWithdrawn = amount - proportionalInterest;
        totalPool[asset] -= principalWithdrawn;
        userPrincipal[msg.sender][asset] -= principalWithdrawn;

        require(IERC20(asset).transfer(msg.sender, userAmount), "Transfer failed");

        emit Withdraw(msg.sender, asset, userAmount);
    }

    function balanceOf(address user, address asset) public view returns (uint256) {
        uint256 index = liquidityIndex[asset];
        return (scaledBalance[user][asset] * index) / RAY;
    }

    function earnedInterest(address user, address asset) public view returns (uint256) {
        uint256 balance = balanceOf(user, asset);
        uint256 principal = userPrincipal[user][asset];

        if (balance <= principal) return 0;

        uint256 rawInterest = balance - principal;
        uint256 interestAfterReserve = rawInterest - ((rawInterest * reserveFactor) / RAY);
        return interestAfterReserve;
    }

    function _updateLiquidityIndex(address asset) internal {
        uint256 timeElapsed = block.timestamp - lastUpdate[asset];
        if (timeElapsed == 0) return;

        uint256 rate = _getRatePerSecond(apy);
        uint256 exp = _rpow(RAY + rate, timeElapsed, RAY);
        liquidityIndex[asset] = (liquidityIndex[asset] * exp) / RAY;

        lastUpdate[asset] = block.timestamp;
    }

    function _getRatePerSecond(uint256 aprPercent) public pure returns (uint256) {
        return ((aprPercent * RAY) / 100) / SECONDS_PER_YEAR;
    }

    function _rpow(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
        z = base;
        while (n > 0) {
            if (n % 2 != 0) {
                z = (z * x) / base;
            }
            x = (x * x) / base;
            n /= 2;
        }
    }
}
