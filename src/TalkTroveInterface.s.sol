//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TalkTrove} from "./TalkTrove.s.sol";
import {GroupContract} from "./TalkTroveGroupC.s.sol";
import {GroupSavings} from "./TalkTroveGroupSavings.s.sol";

contract TalkTroveIn {
    function createAccount() public {}

    function searchUser() public {}

    function sendFriendRequest() public {}

    function acceptFriendRequest() public {}

    function declineFriendRequest() public {}

    function removeFriend() public {}

    function openAGroupWithFriends() public {}

    function createGroupSavings() public {}

    function sendGroupInvite() public {}

    function AcceptGroupInvite() public {}

    function joinGroupSaving() public {}

    function addFundsToGroupSavings() public {}

    function withdrawGroupSavings() internal {}

    function leaveGroup() public {}

    function kickOutOfGroup() public {}

    function pingMutualFriendForMoney() public {}

    function acceptPingAndSend() public {}

    function rejectPing() public {}

    function acceptPing() public {}

    function sendFundsToFriend() public {}

    function claimFunds() public {}

    function reclaimFunds() public {} //@chainlink/contracts/=lib/chainlink-brownie-contracts/contracts/

    function checkUpKeep() public {} //checks upkeep for group saving & auto reclaim

    function performUpKeep() public {} //performs upkeep for group saving & auto reclaim
}
// deploy script
// make in cross chain using ccip. hence refactor it so it can be deployed in two blockchains
// chainlink upkeep for automatic reversal
// covalent network to query
// write tests
