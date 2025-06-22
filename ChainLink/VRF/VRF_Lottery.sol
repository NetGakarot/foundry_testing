// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Lottery is VRFConsumerBaseV2Plus {

    event RequestId(uint256 indexed _requestId);

    address[] public players;
    address public recentWinner;
    uint256 public entranceFee = 0.0001 ether;

    uint256 public s_subscriptionId;
    address public constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 public constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint32 public callbackGasLimit = 100000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;

    constructor(
        uint256 _subId
    ) VRFConsumerBaseV2Plus(VRF_COORDINATOR) {
        s_subscriptionId = _subId;
    }

    function enter() external payable {
        require(msg.value >= entranceFee, "Not enough ETH");
        players.push(msg.sender);
    }

    function drawWinner() public returns(uint256 requestId) {

        requestId = s_vrfCoordinator.requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEY_HASH,
            subId: s_subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestId(requestId);
    }

    function fulfillRandomWords(
        uint256,
        uint256[] calldata randomWords
    ) internal override {
        require(players.length > 0, "No players entered");

        uint256 winnerIndex = randomWords[0] % players.length;
        recentWinner = players[winnerIndex];
        (bool success, ) = payable(recentWinner).call{value:address(this).balance}("");
        require(success, "Failed");

        delete players;
    }

    function getPlayers() external view returns (address[] memory) {
        return players;
    }
}

