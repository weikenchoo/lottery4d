// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "../lib/chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";




/// @title This is a lottery contract, 3 numbers will be picked from 0000 - 9999. 
///        and users who have guessed it correctly will receive a prize according to the prize pool.
/// @author Wei Ken Choo




contract Lottery4d is VRFConsumerBaseV2{

    error Lottery4d__InvalidNumber();
    error Lottery4d__AlreadySubmitted();
    error Lottery4d__NotEnoughEthSent();
    error Lottery4d__CalculatingWinner();
    error Lottery4d__UpkeepNotNeeded(
        uint256 submittedNumbers,
        Lottery4dState lottery4dState
    );

    enum Lottery4dState{
        OPEN,
        CALCULATING
    }


    uint32 private constant WINNING_NUMBERS = 3;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address [] private s_firstPrizeWinners;
    address [] private s_secondPrizeWinners;
    address [] private s_thirdPrizeWinners;

    uint256 [] private s_submittedNumbers;

    uint256 private s_latestTimestamp;
    Lottery4dState private s_lottery4dState;

    
    mapping (uint256 => address[]) private s_submittedNumbersToPlayers;
    

    event NumberSubmitted(address indexed player, uint256 indexed number);
    event WinningNumbers(uint256 indexed firstPrize, uint256 indexed secondPrize, uint256 indexed thirdPrize);
    event PrizeClaimed(address indexed winner, uint256 indexed prizeAmount);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorV2,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lottery4dState = Lottery4dState.OPEN;
    }


    function submitNumber(uint256 number) public payable{
        if (msg.value < i_entranceFee) {
            revert Lottery4d__NotEnoughEthSent();
        }

        if (number < 0 || number > 9999) {
            revert Lottery4d__InvalidNumber();
        }

        if (s_lottery4dState == Lottery4dState.CALCULATING){
            revert Lottery4d__CalculatingWinner();
        }

        if (s_submittedNumbers.length == 0){
            s_latestTimestamp = block.timestamp;
        }


        if (s_submittedNumbersToPlayers[number].length > 0) {
            for (uint256 i = 0; i < s_submittedNumbersToPlayers[number].length; i++) {
                if (s_submittedNumbersToPlayers[number][i] == msg.sender) {
                    revert Lottery4d__AlreadySubmitted();
                }
            }
        } else {
            s_submittedNumbers.push(number);
        }


        
        s_submittedNumbersToPlayers[number].push(msg.sender);
        emit NumberSubmitted(msg.sender, number);
    }


    function checkUpkeep(bytes memory /* checkData */) 
    public 
    view 
    returns (bool upkeepNeeded, bytes memory /* performData */)
    {
         
        bool timePassed = ((block.timestamp - s_latestTimestamp) > i_interval);
        bool isOpen = s_lottery4dState == Lottery4dState.OPEN;
        bool numberSubmitted = (s_submittedNumbers.length > 0);       
        

        upkeepNeeded = (timePassed && isOpen && numberSubmitted);
        return (upkeepNeeded, "");
    }


    function performUpkeep(bytes memory /* checkData */) external returns(uint256){

        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Lottery4d__UpkeepNotNeeded(
                s_submittedNumbers.length,
                s_lottery4dState
            );
        }

        s_lottery4dState = Lottery4dState.CALCULATING;
        
        delete s_firstPrizeWinners;
        delete s_secondPrizeWinners;
        delete s_thirdPrizeWinners;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            WINNING_NUMBERS
        );

        return requestId;

    }


    // select winner and distribute prize should be called inside here
    function fulfillRandomWords(
        uint256 /*_requestId */,
        uint256[] memory _randomWords
    ) internal override {
        _selectWinners(_randomWords);
        _distributePrize();
    }


    function _selectWinners(uint256[] memory randomNumbers)  internal {
        
        uint256 firstPrize;
        uint256 secondPrize;
        uint256 thirdPrize;
        
        for (uint256 i = 0; i < randomNumbers.length; i++) {
            uint256 number = randomNumbers[i] % 10000;
            
            if (i == 0) {
                firstPrize = number;
            } else if(i == 1) {
                secondPrize = number;
            } else if(i == 2){
                thirdPrize = number;
            }

            address[] memory players = s_submittedNumbersToPlayers[number];
            for (uint256 j = 0; j < players.length; j++) {
                if (i == 0) {
                    s_firstPrizeWinners.push(players[j]);
                } else if (i == 1) {
                    s_secondPrizeWinners.push(players[j]);
                } else if (i == 2) {
                    s_thirdPrizeWinners.push(players[j]);
                }
            }
        }

        emit WinningNumbers(firstPrize, secondPrize, thirdPrize);
        
    }

     
    function _distributePrize()  internal {
        uint256 totalFirstPrizeWinners = s_firstPrizeWinners.length;
        uint256 totalSecondPrizeWinners = s_secondPrizeWinners.length;
        uint256 totalThirdPrizeWinners = s_thirdPrizeWinners.length;


        if (totalFirstPrizeWinners > 0 || totalSecondPrizeWinners > 0 || totalThirdPrizeWinners > 0) {
            uint256 prizePool = address(this).balance;
            uint256 firstPrizeAmount = prizePool * 70 / 100;
            uint256 secondPrizeAmount = prizePool * 20 / 100;
            uint256 thirdPrizeAmount = prizePool * 10 / 100;

            uint256 firstPrizePerWinner = totalFirstPrizeWinners > 0 ? firstPrizeAmount / totalFirstPrizeWinners : 0;
            uint256 secondPrizePerWinner = totalSecondPrizeWinners > 0 ? secondPrizeAmount / totalSecondPrizeWinners : 0;
            uint256 thirdPrizePerWinner = totalThirdPrizeWinners > 0 ? thirdPrizeAmount / totalThirdPrizeWinners : 0;

            for (uint256 i = 0; i < totalFirstPrizeWinners; i++) {
                address payable firstPrizeWinner = payable(s_firstPrizeWinners[i]);
                (bool success,) = firstPrizeWinner.call{value: firstPrizePerWinner}("");
                require(success, "Failed to send first prize amount");
                emit PrizeClaimed(firstPrizeWinner, firstPrizePerWinner);
            }

            for (uint256 i = 0; i < totalSecondPrizeWinners; i++) {
                address payable secondPrizeWinner = payable(s_secondPrizeWinners[i]);
                (bool success,) = secondPrizeWinner.call{value: secondPrizePerWinner}("");
                require(success, "Failed to send second prize amount");
                emit PrizeClaimed(secondPrizeWinner, secondPrizePerWinner);
            }

            for (uint256 i = 0; i < totalThirdPrizeWinners; i++) {
                address payable thirdPrizeWinner = payable(s_thirdPrizeWinners[i]);
                (bool success,) = thirdPrizeWinner.call{value: thirdPrizePerWinner}("");
                require(success, "Failed to send third prize amount");
                emit PrizeClaimed(thirdPrizeWinner, thirdPrizePerWinner);
            }
            

        } else{
            emit PrizeClaimed(address(0), 0);
            
        }


        for (uint256 i = 0; i < s_submittedNumbers.length; i++) {
            delete s_submittedNumbersToPlayers[s_submittedNumbers[i]];
        }

        delete s_submittedNumbers;
        s_lottery4dState = Lottery4dState.OPEN;
        
    }


    function getState() external view returns(Lottery4dState){
        return s_lottery4dState;
    }

    function getLatestTimestamp() external view returns(uint256){
        return s_latestTimestamp;
    }

    function getSubmittedNumbers() external view returns(uint256 [] memory){
        return s_submittedNumbers;
    }

    function getSubmittedNumbersToPlayers(uint256 number) external view returns(address [] memory){
        return s_submittedNumbersToPlayers[number];
    }

    function getFirstPrizeWinners() external view returns (address [] memory){
        return s_firstPrizeWinners;
    }

    function getSecondPrizeWinners() external view returns (address [] memory){
        return s_secondPrizeWinners;
    }

    function getThirdPrizeWinners() external view returns (address [] memory){
        return s_thirdPrizeWinners;
    }


}