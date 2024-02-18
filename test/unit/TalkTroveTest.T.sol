//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {TalkTrove} from "../../src/TalkTrove.s.sol";
//import {GroupSavings} from "../../src/TalkTroveGroupSaving.s.sol";
//import {GroupContract} from "../../src/TalkTroveGroupC.s.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TalkTroveTest is StdCheats, Test {
    TalkTrove public talkTrove;
    //GroupSavings public groupSavings;
    //GroupContract public groupChat;

    address asset;
    address avaxPriceFeed;
    address usdt;

    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");
    uint256 public constant STARTING_USER_BALANCE = 11 ether;
    uint256 public constant AMOUNT_TO_SEND = 1 ether;
    //vm.deal(USER1, balance in wei);
    uint256 public constant STARTING_USER_BALANCE2 = 13 ether;
    uint256 public constant goalAmount = 30 ether;
    uint256 public releaseTime = 3;
    uint256 groupId = 1;
    string nameOfGroup = "Test Group";

    error talktrovetest_registrationfailed();

    //event accountCreatedUserRegistered(address indexed userAddress, string username, string additionalInfo);

    function setUp() public {
        talkTrove = new TalkTrove();
        //groupSavings = new GroupSavings();
        //groupChat = new GroupContract();
        vm.deal(USER1, STARTING_USER_BALANCE);
        vm.deal(USER2, STARTING_USER_BALANCE2);
    }

    function testCanCreateAccount() public {
        (bool accountCreated, address id, string memory username) = talkTrove
            .createAccount("emma", "I am a boy");
    }

    function testTwoUserNameDontExist() public {
        vm.prank(USER1);
        (bool accountCreated1, address id1, string memory username1) = talkTrove
            .createAccount("emma", "I am a boy");
        vm.prank(USER2);
        (bool accountCreated2, address id2, string memory username2) = talkTrove
            .createAccount("emma", "I am a boy");
        vm.expectRevert();
    }

    function testOneAddressCantRegisterTwice() public {
        vm.prank(USER1);
        (bool accountCreated1, address id1, string memory username1) = talkTrove
            .createAccount("emma", "I am a boy");
        vm.prank(USER1);
        (bool accountCreated2, address id2, string memory username2) = talkTrove
            .createAccount("emma", "I am a boy");
        vm.expectRevert();
    }

    // function testEmitsEventsWhenUserRegister() public {
    //vm.prank(USER1);
    // (address id1, string memory username1, string memory usersabout) = talkTrove.createAccount("emma", "I am a boy");
    //vm.expectEmit(true, true, false, false, address(talkTrove));
    //emit accountCreatedUserRegistered(USER1, username1, usersabout);
    //}

    function testUserCanSendFriendRequest() public {
        vm.prank(USER1);
        (bool accountCreated1, address id1, string memory username1) = talkTrove
            .createAccount("emma", "i am a boy");
        vm.prank(USER2);
        (bool accountCreated2, address id2, string memory username2) = talkTrove
            .createAccount("chidera", "i am a girl");
        // send request to user 2
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        vm.stopPrank();
    }

    function testRevertsIfRecipientIsNotRegistered() public {
        vm.prank(USER1);
        (bool accountCreated1, address id1, string memory username1) = talkTrove
            .createAccount("emma", "i am a boy");
        //vm.prank(USER2);
        // send request to user 2
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        vm.stopPrank();
        vm.expectRevert();
    }

    function testRevertsIfSenderIsNotRegistered() public {
        vm.prank(USER2);
        (bool accountCreated2, address id2, string memory username2) = talkTrove
            .createAccount("emma", "i am a boy");
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        assertEq(recipient, USER2);
        vm.stopPrank();
        vm.expectRevert();
    }

    function testCanAcceptFriendRequest() public registerUsers {
        // send friend request
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();
    }

    function testCantSendFriendRequestIfAlreadyFriends() public registerUsers {
        // send friend request
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();

        vm.startPrank(USER1);
        address recipientt = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipientt, USER2);
        vm.stopPrank();
        vm.expectRevert();
    }

    function testDeclinesRequest() public registerUsers {
        // send friend request
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to decline friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.declineFriendRequest();
        vm.stopPrank();
    }

    function testCantAcceptRequestIfAlreadyDeclined() public registerUsers {
        // send friend request
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to decline friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.declineFriendRequest();
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();
        vm.expectRevert();
    }

    function testCantDeclineRequestIfAlreadyAccepted() public registerUsers {
        // send friend request
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        // to decline friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.declineFriendRequest();
        vm.stopPrank();
        vm.expectRevert();
    }

    function testCanRemoveFriend() public registerUsers {
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        // to remove friend
        vm.startPrank(USER1);
        talkTrove.removeFriend(USER2);
        vm.stopPrank();
    }

    function testRemoveFriendsRevertIfNotFriends() public registerUsers {
        vm.startPrank(USER1);
        talkTrove.removeFriend(USER2);
        vm.stopPrank();
        vm.expectRevert();
    }

    function testPingMutualFriend() public registerUsers {
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();
        // ping mutual friend
        vm.startPrank(USER1);
        talkTrove.pingMutualFriendForMoney(USER2, AMOUNT_TO_SEND, "forfood");
        vm.stopPrank();
    }

    function testCanAcceptPingAndSend() public registerUsers {
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();
        // ping mutual friend
        vm.startPrank(USER1);
        talkTrove.pingMutualFriendForMoney(USER2, AMOUNT_TO_SEND, "forfood");
        vm.stopPrank();
        // accepts ping
        vm.startPrank(USER2);
        talkTrove.acceptPingAndSend(AMOUNT_TO_SEND);
        vm.stopPrank();
    }

    function testRevertsEthIfPingedConditionWasNotMet() public registerUsers {
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();
        // ping mutual friend
        vm.startPrank(USER1);
        talkTrove.pingMutualFriendForMoney(USER2, AMOUNT_TO_SEND, "forfood");
        vm.stopPrank();
        // accepts ping
        vm.startPrank(USER2);
        payable(talkTrove).transfer(AMOUNT_TO_SEND);
        talkTrove.acceptPingAndSend(AMOUNT_TO_SEND);
        vm.stopPrank();
        //vm.expectRevert();
    }

    function testCantAcceptPingAfterDecline() public registerUsers {
        vm.startPrank(USER1);
        address recipient = talkTrove.sendFriendRequest(USER2);
        // check that request was sent
        assertEq(recipient, USER2);
        // to accept friend request
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptFriendRequest();
        vm.stopPrank();
        // ping mutual friend
        vm.startPrank(USER1);
        talkTrove.pingMutualFriendForMoney(USER2, AMOUNT_TO_SEND, "forfood");
        vm.stopPrank();
        // decline ping
        vm.startPrank(USER2);
        talkTrove.declinePing(USER1);
        vm.stopPrank();
        vm.startPrank(USER2);
        talkTrove.acceptPingAndSend(STARTING_USER_BALANCE);
        vm.stopPrank();
        vm.expectRevert();
    }

    /////////////////////////
    // GROUP SAVINGS TEST ///
    ////////////////////////
    // registerUsers
    function testCanCreateGroupSavings() public registerUsers {
        vm.prank(USER1);
        talkTrove.createSavingsGroup(
            goalAmount,
            releaseTime,
            groupId,
            nameOfGroup
        );
        TalkTrove.SavingsGroup memory talktrove = talkTrove.getSavingsGroups();
        assertEq(talktrove.goalAmount, goalAmount);
    }

    function testCanJoinGroupSavings() public registerUsers {
        vm.startPrank(USER1);
        talkTrove.createSavingsGroup(
            goalAmount,
            releaseTime,
            groupId,
            nameOfGroup
        );
        // talkTrove.joinSavingsGroup(groupId);
        vm.stopPrank();
        //accessesuint256 groupId = 1;
        /// Call the function
        vm.startPrank(USER2);
        talkTrove.joinSavingsGroup(groupId);
        vm.stopPrank();
        vm.startPrank(USER1);
        talkTrove.joinSavingsGroup(groupId);
        vm.stopPrank();
        TalkTrove.SavingsGroup memory talktrove = talkTrove.getSavingsGroups();
        // assertTrue(
        //   groupSavings.isMember(talktrove.groupIdHash, USER1),
        //  "User should have joined the group"
        // );
    }

    function testCanContributeToSavings() public {
        vm.prank(USER1);
        talkTrove.createSavingsGroup(
            goalAmount,
            releaseTime,
            groupId,
            nameOfGroup
        );
        // Call the functions
        talkTrove.joinSavingsGroup(groupId);
        talkTrove.contributeToGroup(groupId, AMOUNT_TO_SEND);
        TalkTrove.SavingsGroup memory talktrove = talkTrove.getSavingsGroups();
        vm.stopPrank();
        assertTrue(
            talkTrove.isMember(talkTrove.groupIdHash, USER1),
            "User should have joined the group"
        );
    }

    function testCanReleaseFunds() public {
        vm.startPrank(USER1);
        groupSavings.createSavingsGroup(
            goalAmount,
            releaseTime,
            groupId,
            nameOfGroup
        );
        payable(groupSavings).transfer(AMOUNT_TO_SEND);
        groupSavings.contributeToGroup(groupId, AMOUNT_TO_SEND);
        vm.warp(block.timestamp + 180 + 1);
        vm.roll(block.number + 180 + 1);
        groupSavings.releaseSavings(groupId);
        GroupSavings.SavingsGroup memory groupsave = groupSavings
            .getSavingsGroups();
        vm.stopPrank();
        assertTrue(
            groupSavings.isMember(groupsave.groupIdHash, USER1),
            "User should have joined the group"
        );
    }

    /////////////////////////////
    ///// GROUP CHAT TEST //////
    ///////////////////////////

    function testCanCreateGroupChat() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
    }

    function testCanSendGroupInvite() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.inviteMember(0, USER2);
    }

    function testCanAcceptInvite() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.inviteMember(0, USER2);
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.acceptInvitation();
        vm.stopPrank();
    }

    function testCanDeclineGroupInvite() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.inviteMember(0, USER2);
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.declineInvitation();
        vm.stopPrank();
    }

    function testCannotAcceptGroupInviteIfAlreadyDecline() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.inviteMember(0, USER2);
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.declineInvitation();
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.acceptInvitation();
        vm.stopPrank();
    }

    function testCannotDeclineInvitationIfAlreadyAccepted() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.inviteMember(0, USER2);
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.acceptInvitation();
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.declineInvitation();
        vm.stopPrank();
    }

    function testCanAddMember() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.addMember(0, USER2, "ejiro");
        vm.stopPrank();
    }

    function testCannotAddAMemberIfAlreadyMember() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.addMember(0, USER2, "ejiro");
        vm.stopPrank();
        vm.startPrank(USER1);
        groupChat.addMember(0, USER2, "ejiro");
        vm.stopPrank();
    }

    function testAssignsAdminWhenInitialAdminLeavesGroup() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.addMember(0, USER2, "ejiro");
        groupChat.assignAdmin(0, USER2);
        vm.stopPrank();
        vm.startPrank(USER1);
        groupChat.adminLeaveGroup(0);
        vm.stopPrank();
    }

    function testCanAssignAdmin() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.addMember(0, USER2, "ejiro");
        groupChat.assignAdmin(0, USER2);
        vm.stopPrank();
    }

    function testCanRemoveMember() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.addMember(0, USER2, "ejiro");
        groupChat.removeMember(0, USER2);
        vm.stopPrank();
    }

    function testMemberCanLeaveGroup() public {
        vm.startPrank(USER1);
        groupChat.createGroup("emma", "group chat test");
        groupChat.addMember(0, USER2, "ejiro");
        vm.stopPrank();
        vm.startPrank(USER2);
        groupChat.userLeaveGroup(0);
    }

    modifier registerUsers() {
        vm.prank(USER1);
        (bool accountCreated1, address id1, string memory username1) = talkTrove
            .createAccount("emma", "i am a boy");
        vm.prank(USER2);
        (bool accountCreated2, address id2, string memory username2) = talkTrove
            .createAccount("chidera", "i am a girl");
        _;
    }
}
