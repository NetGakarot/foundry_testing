// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error InvalidPrice();
error InvalidAddress();

contract DataFeeds is Ownable {
    AggregatorV3Interface public priceFeeds;

    event FeedUpdated(address newFeed, uint256 updatedAt);
    constructor(address _feedAddress, address owner) Ownable(owner) {
         priceFeeds = AggregatorV3Interface(_feedAddress);
    }

    function getDecimals() external view returns(uint256) {
        return priceFeeds.decimals();
    }

    function getETHPriceInUsd() external view returns(int256, uint256) {
        (,int256 price,,uint256 updatedAt,) = priceFeeds.latestRoundData();
        if(price <= 0) revert InvalidPrice();
        return (price,updatedAt);
    }

    function changeFeedAddress(address _feedAddress) external onlyOwner {
        if(_feedAddress == address(0)) revert InvalidAddress();
        priceFeeds = AggregatorV3Interface(_feedAddress);
        emit FeedUpdated(_feedAddress, block.timestamp);
    }

    function getOwner() external view returns(address) {
        return owner();
    }
}