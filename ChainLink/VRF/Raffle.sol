// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
@title Raffle Contract
@author Gakarot
@notice This contract is for creating a sample Raffle
@dev Implement chainlink VRFv2.5
*/

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {

    error Raffle_SendMoreToEnterRaffle();
    error Raffle_TransferFailed();
    error Raffle_RaffleStateNotOpen();
    error LotteryOpen();
    error Raffle_UpkeepNotNeeded(uint256 totalBalance, uint256 totalPlayers, uint256 raffleState);

    enum RaffleState {OPEN, CALCULATING}

    address public constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 public constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 private constant CALLBACK_GASLIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant  NUM_WORDS = 1;

    uint256 private immutable i_enteranceFees;
    uint256 private immutable i_interval;
    uint256 public immutable i_subscriptionId;

    uint256 private s_lastTimeStamp;
    address public s_recentWinner;
    address payable [] private s_players;
    RaffleState private s_raffleState;

    event RaffleEntered(address indexed player);
    event  WinnerPicked(address indexed winner);

    constructor(uint256 enteranceFees, uint256 interval, uint256 subId) VRFConsumerBaseV2Plus(VRF_COORDINATOR) {
        i_enteranceFees = enteranceFees;
        i_interval = interval;
        i_subscriptionId = subId;

        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if(msg.value < i_enteranceFees) revert Raffle_SendMoreToEnterRaffle(); 
        if(s_raffleState != RaffleState.OPEN) revert Raffle_RaffleStateNotOpen();
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes memory) public view override returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return(upkeepNeeded,"");
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded) revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        _pickWinner();
    }

    function _pickWinner() internal returns(uint256 requestId) {
        if((block.timestamp - s_lastTimeStamp) < i_interval) revert LotteryOpen();
        s_raffleState = RaffleState.CALCULATING;

        requestId = s_vrfCoordinator.requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEY_HASH,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: CALLBACK_GASLIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override  {
        if(s_players.length == 0) revert();
        uint256 winnerIndex = randomWords[0] % s_players.length;
        s_recentWinner = s_players[winnerIndex];

        (bool success, ) = payable(s_recentWinner).call{value:address(this).balance}("");
        if(!success) revert Raffle_TransferFailed();

        emit WinnerPicked(s_recentWinner);

        delete s_players;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function getEnteranceFees() external view returns(uint256) {
        return i_enteranceFees;
    }

    function getplayers() external view returns(address payable[] memory) {
        return s_players;
    }
}
