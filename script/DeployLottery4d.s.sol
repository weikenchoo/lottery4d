// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Lottery4d} from "../src/Lottery4d.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";


contract DeployLottery4d is Script{

    


    function run() external returns (Lottery4d, HelperConfig){
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig helperConfig = new HelperConfig();
        
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinatorV2,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            FundSubscription fundSubscription = new FundSubscription();
            
            subscriptionId = createSubscription.createSubscription(vrfCoordinatorV2,deployerKey);

            fundSubscription.fundSubscription(
                vrfCoordinatorV2,
                subscriptionId,
                link,
                deployerKey
            );

        }

        vm.startBroadcast(deployerKey);

        Lottery4d lottery4d = new Lottery4d(
            entranceFee,
            interval,
            vrfCoordinatorV2,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );

        vm.stopBroadcast();
        

        addConsumer.addConsumer(address(lottery4d), vrfCoordinatorV2, subscriptionId, deployerKey);


        return (lottery4d, helperConfig);
        
    }
}