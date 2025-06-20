// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMyToken {
    function mint(address account, uint256 value) external;
}

error InvalidPrice();
error InvalidAddress();
error InvalidThreshold();

contract AutoFeed is Ownable,AutomationCompatibleInterface {

    int256 public latestPrice;
    uint256 public lastTimeStamp;
    uint256 public interval;
    int256 public lowerThreshold;
    int256 public upperThreshold;

    AggregatorV3Interface public priceFeed;
    IMyToken immutable token;

    event FeedUpdated(address newFeed, uint256 updatedAt);
    event PriceUpdated(int256 price, uint256 timestamp);
    event TokenMinted(address to, uint256 amount, int256 priceAtMint);

    constructor(address _token,uint256 _interval, address _priceFeeds, address owner, int256 _lowerThreshold, int256 _upperThreshold) Ownable(owner) {
        priceFeed = AggregatorV3Interface(_priceFeeds);
        interval = _interval;
        lowerThreshold = _lowerThreshold;
        upperThreshold = _upperThreshold;
        token = IMyToken(_token);
    }

    function getDecimals() public view returns(uint256) {
        return priceFeed.decimals();

    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        if((block.timestamp - lastTimeStamp) > interval) {
            (,int256 _price,,,) = priceFeed.latestRoundData();
            if(_price > upperThreshold || _price < lowerThreshold) {
                upkeepNeeded = true;
            } else {
                upkeepNeeded = false;
            }
        }
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            (,int256 _price,,,) = priceFeed.latestRoundData();
            if(_price > upperThreshold || _price < lowerThreshold) {
                _getLatestPrice();
                _mintTokens();
                return;
            }
        }

        revert("Upkeep not needed");
    }

    function getPrice() external view returns(int256, uint256) {
        return (latestPrice,lastTimeStamp);
    }

    function changeFeedAddress(address _feedAddress) external onlyOwner {
        if(_feedAddress == address(0)) revert InvalidAddress();
        priceFeed = AggregatorV3Interface(_feedAddress);
        emit FeedUpdated(_feedAddress, block.timestamp);
    }

    function changeUpperThreshold(int256 _threshold) external onlyOwner {
        if(_threshold <= 0) revert InvalidThreshold();
        upperThreshold = _threshold;
    }
    function changeLowerThreshold(int256 _threshold) external onlyOwner {
        if(_threshold <= 0) revert InvalidThreshold();
        lowerThreshold = _threshold;
    }

    function getOwner() external view returns(address) {
        return owner();
    }

    function getThresholds() external view returns (int256, int256) {
        return (lowerThreshold, upperThreshold);
    }

    function getPriceFeedAddress() external view returns (address) {
        return address(priceFeed);
    }

    function getTokenAddress() external view returns (address) {
        return address(token);
    }

    function _mintTokens() internal {
        token.mint(owner(), 100e18);
        emit TokenMinted(owner(), 100e18, latestPrice);
    }

    function _getLatestPrice() internal {
        (,int256 price,,uint256 updatedAt,) = priceFeed.latestRoundData();
        if(price <= 0) revert InvalidPrice();
        latestPrice = price;
        lastTimeStamp = block.timestamp;
        emit PriceUpdated(latestPrice, updatedAt);
    }
}

