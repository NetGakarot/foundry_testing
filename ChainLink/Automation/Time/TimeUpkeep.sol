// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error InvalidPrice();
error InvalidAddress();

contract AutoFeed is Ownable,AutomationCompatibleInterface {

    int256 public latestPrice;
    uint256 public lastTimeStamp;
    uint256 public interval;
    AggregatorV3Interface public priceFeed;

    event FeedUpdated(address newFeed, uint256 updatedAt);
    event PriceUpdated(int256 price, uint256 timestamp);

    constructor(uint256 _interval, address _priceFeeds, address owner) Ownable(owner) {
        priceFeed = AggregatorV3Interface(_priceFeeds);
        interval = _interval;
    }

    function getDecimals() public view returns(uint256) {
        return priceFeed.decimals();

    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            _getLatestPrice();
        }
    }

    function getPrice() external view returns(int256, uint256) {
        return (latestPrice,lastTimeStamp);
    }

    function changeFeedAddress(address _feedAddress) external onlyOwner {
        if(_feedAddress == address(0)) revert InvalidAddress();
        priceFeed = AggregatorV3Interface(_feedAddress);
        emit FeedUpdated(_feedAddress, block.timestamp);
    }

    function getOwner() external view returns(address) {
        return owner();
    }

    function _getLatestPrice() internal {
        (,int256 price,,uint256 updatedAt,) = priceFeed.latestRoundData();
            if(price <= 0) revert InvalidPrice();
            latestPrice = price / int256(10 ** getDecimals());
            lastTimeStamp = updatedAt;
            emit PriceUpdated(latestPrice, updatedAt);
    }
}
