// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol"; 
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {DeployLottery4d} from "../../script/DeployLottery4d.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Lottery4d} from "../../src/Lottery4d.sol";
import {VRFCoordinatorV2Mock} from "../../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract Lottery4dTest is Test{

    Lottery4d lottery4d;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinatorV2;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER1 = makeAddr("player1");
    address public PLAYER2 = makeAddr("player2");
    address public PLAYER3 = makeAddr("player3");
    uint256 public constant USER_BALANCE = 10 ether;

    event NumberSubmitted(address indexed player, uint256 indexed number);
    event WinningNumbers(uint256 indexed firstPrize, uint256 indexed secondPrize, uint256 indexed thirdPrize);
    event PrizeClaimed(address indexed winner, uint256 indexed prizeAmount);
    

    function setUp() external{
        DeployLottery4d deployer = new DeployLottery4d();
        (lottery4d, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinatorV2,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            ,
            
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER1,USER_BALANCE);
        vm.deal(PLAYER2,USER_BALANCE);
        vm.deal(PLAYER3,USER_BALANCE);
        
    }

    modifier playersSubmitNumbers(){
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(6461);

        vm.prank(PLAYER2);
        lottery4d.submitNumber{value:entranceFee}(1599);

        vm.prank(PLAYER3);
        lottery4d.submitNumber{value:entranceFee}(9136);

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        _;
    }

    modifier skipFork(){
        if(block.chainid != 31337){
            return;
        }
        _;
    }

    function testLotteryInitializesInOpenState() public view {
        assert(lottery4d.getState() == Lottery4d.Lottery4dState.OPEN);
    }


    function testLotteryRevertsWhenNotEnoughEth() public {
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery4d.Lottery4d__NotEnoughEthSent.selector);
        lottery4d.submitNumber(1111);

    }

    function testLotteryRevertsWhenNotValidNumber() public {
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery4d.Lottery4d__InvalidNumber.selector);
        lottery4d.submitNumber{value:entranceFee}(10000);

    }

    function testLotteryRevertsIfUserSubmitsSameNumber() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery4d.Lottery4d__AlreadySubmitted.selector);
        lottery4d.submitNumber{value:entranceFee}(9999);
        
    }

    function testTimestampGetsInitiatedWhenFirstPlayerSubmitsANumber() public{
        assertEq(lottery4d.getLatestTimestamp(),0 );
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        assertEq(lottery4d.getLatestTimestamp(),block.timestamp );

    } 

    function testLotteryRevertsIfUserSubmitsAfterStartPickingWinners() public playersSubmitNumbers(){
        
        lottery4d.performUpkeep("");
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery4d.Lottery4d__CalculatingWinner.selector);
        lottery4d.submitNumber{value:entranceFee}(9999);
    }

    function testCheckUpkeepReturnsFalseIfNoSubmittedNumber() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery4d.checkUpkeep("");
        assertEq(upkeepNeeded,false);

    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.warp(block.timestamp + interval - 50);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery4d.checkUpkeep("");
        assertEq(upkeepNeeded,false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery4d.checkUpkeep("");
        assertEq(upkeepNeeded,true);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        lottery4d.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {

        uint256 numbersSubmitted = 0;
        Lottery4d.Lottery4dState lottery4dState = lottery4d.getState();

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery4d.Lottery4d__UpkeepNotNeeded.selector,
                numbersSubmitted,
                lottery4dState
            )
        );

        lottery4d.performUpkeep("");
    }



    function testIfNumberIsAddedIntoSubmittedNumbersArray() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        
        uint256[] memory submittedNumbers =lottery4d.getSubmittedNumbers();

        assert(submittedNumbers[0] == 9999);
    }

    function testIfExistingNumberWillBeAddedIntoSubmittedNumbersArray() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.prank(PLAYER2);
        lottery4d.submitNumber{value:entranceFee}(9999);

        uint256[] memory submittedNumbers =lottery4d.getSubmittedNumbers();

        assert(submittedNumbers.length == 1);
        assert(submittedNumbers[0] == 9999);
    }

    function testSamePlayerSubmitMultipleDifferentNumbers() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(1111);

        uint256[] memory submittedNumbers =lottery4d.getSubmittedNumbers();
        address[] memory firstNumToPlayer = lottery4d.getSubmittedNumbersToPlayers(9999);
        address[] memory secondNumToPlayer = lottery4d.getSubmittedNumbersToPlayers(1111);

        assert(submittedNumbers.length == 2);
        assert(firstNumToPlayer[0] == PLAYER1);
        assert(secondNumToPlayer[0]== PLAYER1);
        
    }

    function testIfPlayersAddressWillBeAddedIntoMapping() public{
        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);
        vm.prank(PLAYER2);
        lottery4d.submitNumber{value:entranceFee}(9999);

        address [] memory playerAddresses = lottery4d.getSubmittedNumbersToPlayers(9999);

        playerAddresses[0] == PLAYER1;
        assert(playerAddresses.length == 2);
        assert(playerAddresses[0] == PLAYER1);
        assert(playerAddresses[1] == PLAYER2);

    }

    function testIfEventIsEmittedWhenNumberIsSubmitted() public{
        vm.prank(PLAYER1);
        vm.expectEmit(true,true,false,false,address(lottery4d));
        emit NumberSubmitted(PLAYER1,9999);
        lottery4d.submitNumber{value:entranceFee}(9999);
    }


    // To test
    // function pickWinningNumber
    // - test if can get 3 winning numbers
    // - test if prize money is distributed properly
    // - test if correct events are being emitted

    

    function testSubmittedNumberMappingIsReset() public playersSubmitNumbers() skipFork(){

        uint256[] memory allNumbers = lottery4d.getSubmittedNumbers();
        assertEq(allNumbers.length, 3);

        uint256 requestId = lottery4d.performUpkeep("");
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(requestId, address(lottery4d));

        address [] memory emptyPlayersArray;
        uint256 [] memory emptySubmittedNumbersArray;

        for (uint256 i = 0; i < allNumbers.length; i++) {
            assertEq(lottery4d.getSubmittedNumbersToPlayers(allNumbers[i]),emptyPlayersArray );
        }

        assertEq(lottery4d.getSubmittedNumbers(), emptySubmittedNumbersArray);

        
    }

    function testWinnerArrayIsReset() public playersSubmitNumbers(){

        address [] memory emptyWinnersArray;

        lottery4d.performUpkeep("");
        assertEq(lottery4d.getFirstPrizeWinners(), emptyWinnersArray);
        assertEq(lottery4d.getSecondPrizeWinners(), emptyWinnersArray);
        assertEq(lottery4d.getThirdPrizeWinners(), emptyWinnersArray);
        
    }

    function testEmitEventAndPrizeAmountWhenMultipleWinnerInEachPrize() public playersSubmitNumbers() skipFork(){

        address secondWinner = makeAddr("player4");
        vm.deal(secondWinner, USER_BALANCE);

        vm.prank(secondWinner);
        lottery4d.submitNumber{value: entranceFee}(6461);
        vm.prank(secondWinner);
        lottery4d.submitNumber{value: entranceFee}(1599);
        vm.prank(secondWinner);
        lottery4d.submitNumber{value: entranceFee}(9136);

        

        for (uint256 i = 0; i < 10; i++) {
            address player = address(uint160(i));
            hoax(player, USER_BALANCE); 
            lottery4d.submitNumber{value: entranceFee}(i);
        }

        uint256 totalPrize = address(lottery4d).balance;
        console.log(totalPrize);

        uint256 requestId = lottery4d.performUpkeep("");
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(requestId, address(lottery4d));

        uint256 totalFirstPrizeWinners = lottery4d.getFirstPrizeWinners().length;
        uint256 totalSecondPrizeWinners = lottery4d.getSecondPrizeWinners().length;
        uint256 totalThirdPrizeWinners = lottery4d.getThirdPrizeWinners().length;


        uint256 firstPrizeAmount = totalPrize * 70 / 100;
        uint256 secondPrizeAmount = totalPrize * 20 / 100;
        uint256 thirdPrizeAmount = totalPrize * 10 / 100;

        console.log(firstPrizeAmount);
        console.log(secondPrizeAmount);
        console.log(thirdPrizeAmount);

        uint256 firstPrizePerWinner = totalFirstPrizeWinners > 0 ? firstPrizeAmount / totalFirstPrizeWinners : 0;
        uint256 secondPrizePerWinner = totalSecondPrizeWinners > 0 ? secondPrizeAmount / totalSecondPrizeWinners : 0;
        uint256 thirdPrizePerWinner = totalThirdPrizeWinners > 0 ? thirdPrizeAmount / totalThirdPrizeWinners : 0;

        console.log(firstPrizePerWinner);
        console.log(secondPrizePerWinner);
        console.log(thirdPrizePerWinner);

        

        assert(PLAYER1.balance == firstPrizePerWinner + USER_BALANCE - entranceFee);
        assert(PLAYER2.balance == secondPrizePerWinner + USER_BALANCE - entranceFee);
        assert(PLAYER3.balance == thirdPrizePerWinner + USER_BALANCE - entranceFee);
        assert(secondWinner.balance == firstPrizePerWinner + secondPrizePerWinner + thirdPrizePerWinner + USER_BALANCE - (entranceFee*3));

    }



    function testEmitEventAndPrizeAmountWhenSingleWinnerInEachPrize() public playersSubmitNumbers() skipFork(){
        
        uint256 totalPrize = entranceFee *3;
        uint256 firstPrizeAmount = totalPrize * 70 / 100;
        uint256 secondPrizeAmount = totalPrize * 20 / 100;
        uint256 thirdPrizeAmount = totalPrize * 10 / 100;

        uint256 requestId = lottery4d.performUpkeep("");

        vm.expectEmit(true, true, true, false,address(lottery4d));
        emit WinningNumbers(6461,1599,9136);

        vm.expectEmit(true, true, false, false, address(lottery4d));
        emit PrizeClaimed(address(PLAYER1), firstPrizeAmount);

        vm.expectEmit(true, true, false, false, address(lottery4d));
        emit PrizeClaimed(address(PLAYER2), secondPrizeAmount);

        vm.expectEmit(true, true, false, false, address(lottery4d));
        emit PrizeClaimed(address(PLAYER3), thirdPrizeAmount);

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(requestId, address(lottery4d));

        assert(PLAYER1.balance == firstPrizeAmount + USER_BALANCE - entranceFee);
        assert(PLAYER2.balance == secondPrizeAmount + USER_BALANCE - entranceFee);
        assert(PLAYER3.balance == thirdPrizeAmount + USER_BALANCE - entranceFee);

    }



    function testFulfillRandomWords() public skipFork(){

        vm.prank(PLAYER1);
        lottery4d.submitNumber{value:entranceFee}(9999);

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        
        uint256 requestId = lottery4d.performUpkeep("");

        assert(lottery4d.getState() == Lottery4d.Lottery4dState.CALCULATING);

        vm.recordLogs();
        vm.expectEmit(true, true, true, false, address(lottery4d));
        emit WinningNumbers(6461, 1599, 9136);
        vm.expectEmit(true, true, false, false, address(lottery4d));
        emit PrizeClaimed(address(0), 0);

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(requestId, address(lottery4d));

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 firstPrize = entries[0].topics[1];
        bytes32 secondPrize = entries[0].topics[2];
        bytes32 thirdPrize = entries[0].topics[3];
        
        assert(uint256(firstPrize) >= 0 && uint256(firstPrize) < 10000 );
        assert(uint256(secondPrize) >= 0 && uint256(secondPrize) < 10000 );
        assert(uint256(thirdPrize) >= 0 && uint256(thirdPrize) < 10000 );

        assert(lottery4d.getState() == Lottery4d.Lottery4dState.OPEN);

    }







    



}