// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error InvalidPrice();

contract DataFeeds {
    AggregatorV3Interface public immutable priceFeeds;
    constructor(address _feedAddress) {
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
}