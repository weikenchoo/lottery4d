// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script, console} from "../lib/forge-std/src/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinatorV2;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    event HelperConfig__CreatedMockVRFCoordinator(address vrfCoordinator);

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            subscriptionId: 275, // If left as 0, our scripts will create one!
            interval:86400, // 24 hours
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            link:0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey:vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        // Check to see if we set an active network config
        if (activeNetworkConfig.vrfCoordinatorV2 != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;

        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY);
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );

        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        emit HelperConfig__CreatedMockVRFCoordinator(
            address(vrfCoordinatorV2Mock)
        );

        console.log(address(vrfCoordinatorV2Mock));
        console.log(address(link));

        anvilNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            interval:60, // 24 hours
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2: address(vrfCoordinatorV2Mock),
            link: address(link),
            deployerKey:DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}