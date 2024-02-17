// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TalkTrove} from "../src/TalkTrove.s.sol";

contract DeployTalkTrove is Script {
    function run() external returns (TalkTrove, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        address priceFeed = helperConfig.activeNetworkConfig();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast();
        TalkTrove talkTrove = new TalkTrove(priceFeed);
        vm.stopBroadcast();
        return (talkTrove, helperConfig);
    }
}
