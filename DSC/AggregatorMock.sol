// contracts/test/MockV3Aggregator.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockV3Aggregator is AggregatorV3Interface {
    int256 private answer;
    uint8 private _decimals;

    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals = decimals_;
        answer = initialAnswer;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, answer, 0, 0, 0);
    }

    // stubbed, required to match interface
    function description() external pure override returns (string memory) {
        return "MockV3Aggregator";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        pure
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, 0, 0, 0, _roundId);
    }

    function changeAnswer(int256 _answer) external {
        answer = _answer;
    }
}
