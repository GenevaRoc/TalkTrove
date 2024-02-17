// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {GroupSavings} from "./TalkTroveGroupSaving.s.sol";
import {TalkTrove} from "./TalkTrove.s.sol";

contract GroupContract {
    struct User {
        uint256 id;
        string username;
        bool isMember;
        bool isAdmin;
    }

    struct Group {
        address owner;
        mapping(address => User) members;
        address[] admins;
        address[] memberList;
    }

    struct Invitation {
        uint256 groupId;
        bool isPending;
    }

    mapping(uint256 => Group) public groups;
    mapping(address => Invitation) public invitations;
    mapping(address => uint256[]) public userGroups;
    uint256 public nextGroupId;

    // Custom errors
    error OnlyGroupOwnerAllowed();
    error UserAlreadyMember();
    error UserNotMember();
    error UserNotAdmin();
    error NoPendingInvitation();
    error NoGroupOwnerChangeToMember();
    error TransferToExistingAdmin();

    error TalkTrove_MustBeRegistered();

    event GroupCreated(uint256 indexed groupId, address indexed owner);
    event OwnershipTransferred(uint256 indexed groupId, address indexed previousOwner, address indexed newOwner);
    event MemberAdded(uint256 indexed groupId, address indexed member);
    event MemberRemoved(uint256 indexed groupId, address indexed member);
    event MemberInvited(uint256 indexed groupId, address indexed member);
    event MemberJoined(uint256 indexed groupId, address indexed member);
    event InvitationDeclined(address indexed member);
    event AdminAdded(uint256 indexed groupId, address indexed admin);
    event AdminRemoved(uint256 indexed groupId, address indexed admin);
    event MemberLeftGroup(uint256 indexed groupId, address indexed member);

    GroupSavings private immutable i_TTGS;
    TalkTrove private immutable i_TT;

    // Function to create a new group
    function createGroup(string calldata username) external returns (uint256 groupId) {
        groupId = nextGroupId++;
        Group storage group = groups[groupId];
        group.owner = msg.sender;
        group.members[msg.sender] = User({id: groupId, username: username, isMember: true, isAdmin: true});
        group.admins.push(msg.sender);
        group.memberList.push(msg.sender);

        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        emit GroupCreated(groupId, msg.sender);
        return groupId;
    }

    // Function to invite a new member
    function inviteMember(uint256 groupId, address newMember) external {
        if (groups[groupId].owner == msg.sender || groups[groupId].members[msg.sender].isAdmin) revert UserNotAdmin();
        if (groups[groupId].members[newMember].isMember) {
            revert UserAlreadyMember();
        }

        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }
        bool memberisUser = i_TT._checkUserIsRegistered(newMember);
        if (!memberisUser) {
            revert TalkTrove_MustBeRegistered();
        }

        invitations[newMember] = Invitation({groupId: groupId, isPending: true});

        emit MemberInvited(groupId, newMember);
    }

    // Function for a user to accept an invitation
    function acceptInvitation() external {
        if (invitations[msg.sender].isPending) revert NoPendingInvitation();
        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        uint256 groupId = invitations[msg.sender].groupId;
        groups[groupId].members[msg.sender] = User({
            id: groupId,
            username: "", // Username to be set by user
            isMember: true,
            isAdmin: false
        });
        groups[groupId].memberList.push(msg.sender);

        delete invitations[msg.sender];
        emit MemberJoined(groupId, msg.sender);
    }

    // Function for a user to decline an invitation
    function declineInvitation() external {
        if (invitations[msg.sender].isPending) revert NoPendingInvitation();
        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        delete invitations[msg.sender];
        emit InvitationDeclined(msg.sender);
    }

    // Function to add a new member
    function addMember(uint256 groupId, address newMember, string calldata username) external {
        if (msg.sender != groups[groupId].owner) revert OnlyGroupOwnerAllowed();
        if (groups[groupId].members[newMember].isMember) {
            revert UserAlreadyMember();
        }
        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }
        bool memberisUser = i_TT._checkUserIsRegistered(newMember);
        if (!memberisUser) {
            revert TalkTrove_MustBeRegistered();
        }

        groups[groupId].members[newMember] = User({id: groupId, username: username, isMember: true, isAdmin: false});
        groups[groupId].memberList.push(newMember);

        emit MemberAdded(groupId, newMember);
    }

    function adminLeaveGroup(uint256 groupId) external {
        if (!groups[groupId].members[msg.sender].isMember) {
            revert UserNotMember();
        }

        if (msg.sender == groups[groupId].owner) {
            address newOwner = address(0);

            // Check if there are any admins
            if (groups[groupId].admins.length > 0) {
                // Transfer ownership to a random admin
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1))))
                    % groups[groupId].admins.length;
                newOwner = groups[groupId].admins[randomIndex];
            } else {
                // No admins, transfer ownership to a random member
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1))))
                    % groups[groupId].memberList.length;
                newOwner = groups[groupId].memberList[randomIndex];
            }

            if (newOwner != address(0)) {
                groups[groupId].owner = newOwner;
                groups[groupId].members[newOwner].isAdmin = true; // Ensure the new owner is an admin
                emit OwnershipTransferred(groupId, msg.sender, newOwner);
            } else {
                // No members left, delete the group
                delete groups[groupId];
            }
        }

        // Remove member from group
        removeMemberFromGroup(groupId, msg.sender);
    }

    // Function to assign admin role
    function assignAdmin(uint256 groupId, address member) external {
        if (msg.sender != groups[groupId].owner) revert OnlyGroupOwnerAllowed();
        if (!groups[groupId].members[member].isMember) revert UserNotMember();
        if (groups[groupId].members[member].isAdmin) {
            revert TransferToExistingAdmin();
        }
        bool isUser = i_TT._checkUserIsRegistered(member);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        groups[groupId].members[member].isAdmin = true;
        groups[groupId].admins.push(member);

        emit AdminAdded(groupId, member);
    }

    // Function to remove a member
    function removeMember(uint256 groupId, address member) external {
        if (msg.sender != groups[groupId].owner && !groups[groupId].members[msg.sender].isAdmin) {
            revert OnlyGroupOwnerAllowed();
        }
        bool memberisUser = i_TT._checkUserIsRegistered(member);
        if (!memberisUser) {
            revert TalkTrove_MustBeRegistered();
        }
        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }
        if (!groups[groupId].members[member].isMember) revert UserNotMember();

        removeMemberFromGroup(groupId, member);
    }

    // Function for a user to leave a group
    function userLeaveGroup(uint256 groupId) external {
        if (!groups[groupId].members[msg.sender].isMember) {
            revert UserNotMember();
        }
        bool isUser = i_TT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        // Remove user from the group's members array
        Group storage group = groups[groupId];

        // Find the index of the member in the memberList
        uint256 indexToRemove = type(uint256).max;
        for (uint256 i = 0; i < group.memberList.length; i++) {
            if (group.memberList[i] == msg.sender) {
                indexToRemove = i;
                break;
            }
        }

        // If the member is found in the memberList, remove them
        if (indexToRemove < group.memberList.length) {
            group.memberList[indexToRemove] = group.memberList[group.memberList.length - 1];
            group.memberList.pop();
        }

        // Set isMember and isAdmin to false for the leaving member
        group.members[msg.sender].isMember = false;
        group.members[msg.sender].isAdmin = false;

        emit MemberLeftGroup(groupId, msg.sender);
    }

    // Internal function to remove a member from the group
    function removeMemberFromGroup(uint256 groupId, address member) internal {
        if (!groups[groupId].members[member].isMember) revert UserNotMember();
        delete groups[groupId].members[member];
        for (uint256 i = 0; i < groups[groupId].memberList.length; i++) {
            if (groups[groupId].memberList[i] == member) {
                groups[groupId].memberList[i] = groups[groupId].memberList[groups[groupId].memberList.length - 1];
                groups[groupId].memberList.pop();
                break;
            }
        }
        emit MemberRemoved(groupId, member);
    }
}
