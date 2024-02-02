//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TalkTrove} from "./TalkTrove.s.sol";
import {GroupContract} from "./TalkTroveGroupC.s.sol";

contract GroupSavings {
    struct SavingsGroup {
        address creator;
        uint256 goalAmount;
        uint256 releaseTime;
        mapping(address => uint256) contributions;
        mapping(address => bool) members;
        address[] contributors;
    }

    error TalkTrove_ReleaseTimeMustBeInFuture();
    error TalkTrove_SavingsDoesNotExist();
    error TalkTrove_AlreadyAMember();
    error TalkRove_NotAMemberOfGroupSavings();
    error TalkTrove_SavingsPeriodHasEnded();
    error TalkTrove_OnlyMemberCanReleaseFunds();
    error TalkTrove_SavingsPeriodNotEndedYet();
    error TalkTrove_MustBeRegistered();

    SavingsGroup[] public savingsGroups;

    event NewSavingsGroup(
        uint256 indexed groupId,
        address indexed creator,
        uint256 goalAmount,
        uint256 releaseTime
    );
    event Contribution(
        uint256 indexed groupId,
        address indexed contributor,
        uint256 amount
    );
    event FundsReleased(uint256 indexed groupId, uint256 amount);

    TalkTrove private immutable i_tT;
    GroupContract private immutable i_tTGC;

    function createSavingsGroup(
        uint256 _goalAmount,
        uint256 _releaseTime
    ) external {
        if (_releaseTime > block.timestamp) {
            revert TalkTrove_ReleaseTimeMustBeInFuture();
        }

        bool isUser = i_tT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }
        savingsGroups.push();
        uint256 newGroupId = savingsGroups.length - 1;
        SavingsGroup storage group = savingsGroups[newGroupId];
        group.creator = msg.sender;
        group.goalAmount = _goalAmount;
        group.releaseTime = _releaseTime;
        emit NewSavingsGroup(newGroupId, msg.sender, _goalAmount, _releaseTime);
    }

    function joinSavingsGroup(uint256 _groupId) external {
        SavingsGroup storage group = savingsGroups[_groupId];
        if (group.creator == address(0)) {
            revert TalkTrove_SavingsDoesNotExist();
        }
        if (group.members[msg.sender]) {
            revert TalkTrove_AlreadyAMember();
        }
        bool isUser = i_tT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }
        group.members[msg.sender] = true;
    }

    function contribute(uint256 _groupId) external payable {
        SavingsGroup storage group = savingsGroups[_groupId];
        if (group.creator == address(0)) {
            revert TalkTrove_SavingsDoesNotExist();
        }
        if (!group.members[msg.sender]) {
            revert TalkRove_NotAMemberOfGroupSavings();
        }
        if (block.timestamp >= group.releaseTime) {
            revert TalkTrove_SavingsPeriodHasEnded();
        }
        bool isUser = i_tT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }
        group.contributions[msg.sender] += msg.value;
        group.contributors.push(msg.sender);
        emit Contribution(_groupId, msg.sender, msg.value);
    }

    function releaseFunds(uint256 _groupId) external {
        SavingsGroup storage group = savingsGroups[_groupId];
        if (!group.members[msg.sender]) {
            revert TalkTrove_OnlyMemberCanReleaseFunds();
        }
        if (block.timestamp < group.releaseTime) {
            revert TalkTrove_SavingsPeriodNotEndedYet();
        }

        bool isUser = i_tT._checkUserIsRegistered(msg.sender);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        for (uint256 i = 0; i < group.contributors.length; i++) {
            address payable contributor = payable(group.contributors[i]); // Convert address to payable
            uint256 contribution = group.contributions[contributor];
            contributor.transfer(contribution);
        }

        emit FundsReleased(_groupId, address(this).balance);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
