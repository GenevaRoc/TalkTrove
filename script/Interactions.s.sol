// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {TalkTrove} from "../src/TalkTrove.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract ContributeTalkTroveGroupSaving is Script {
    uint256 SEND_VALUE = 0.1 ether;

    function contributeTalkTroveGroupSaving(
        address mostRecentlyDeployed
    ) public {
        vm.startBroadcast();
        TalkTrove(payable(mostRecentlyDeployed)).contributeToGroup{
            value: SEND_VALUE
        }(0, 0);
        vm.stopBroadcast();
        console.log("Contributed to TalkTroveGroupSavingwith %s", SEND_VALUE);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "TalkTrovesGroupSaving",
            block.chainid
        );
        contributeTalkTroveGroupSaving(mostRecentlyDeployed);
    }
}

contract ReleaseTalkTroveGroupSaving is Script {
    function releaseTalkTroveGroupSaving(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        TalkTrove(payable(mostRecentlyDeployed)).releaseSavings(0);
        vm.stopBroadcast();
        console.log("Releaase TalkTroveGroupSaving balance!");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "TalkTroveGroupSaving",
            block.chainid
        );
        releaseTalkTroveGroupSaving(mostRecentlyDeployed);
    }
}
