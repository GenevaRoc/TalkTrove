// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TalkTrove} from "./TalkTrove.s.sol";
import {GroupContract} from "./TalkTroveGroupC.s.sol";

contract GroupSavings {
    struct Deposit {
        address depositor;
        uint256 amount;
    }

    error NotGroupOwner();
    error NotAMember();
    error ReleaseTimeNotReached();
    error TransferFailed();
    error SavingExisting();

    address public owner;
    IERC20 public token;
    uint256 public releaseTime;
    mapping(address => uint256) public balances;
    Deposit[] public deposits;
    mapping(address => bool) public isMember;
    address[] public members;
    uint256 public totalDeposites;
    //  mapping(address => Member) public members;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotGroupOwner();
        _;
    }

    modifier onlyParticipant() {
        if (!isMember[msg.sender]) revert NotAMember();
        _;
    }

    event JoinedGroupSavings(address indexed member);
    event DepositedFunds(address indexed depositor, uint256 amount);
    event DispersedFunds(address indexed member, uint256 amount);
    event RemovedFromGroupSavings(address indexed member);

    constructor(IERC20 _token) {
        owner = msg.sender;
        token = _token;
    }

    function createGroupSavings(
        IERC20 _token,
        uint256 _releaseTime
    ) external onlyOwner {
        //if(!owner == address(0)) revert SavingExisting();

        owner = msg.sender;
        token = _token;
        releaseTime = _releaseTime;

        emit JoinedGroupSavings(owner);
    }

    function joinGroupSavings() external {
        isMember[msg.sender] = true;
        members.push(msg.sender);
        emit JoinedGroupSavings(msg.sender);
    }

    function depositFunds(uint256 _amount) external onlyParticipant {
        if (!token.transferFrom(msg.sender, address(this), _amount))
            revert TransferFailed();
        balances[msg.sender] += _amount;
        deposits.push(Deposit(msg.sender, _amount));
        totalDeposites += _amount;
        emit DepositedFunds(msg.sender, _amount);
    }

    function removeFromGroupSavings(address _member) external onlyOwner {
        isMember[_member] = false;
        emit RemovedFromGroupSavings(_member);
    }

    function distributeFunds() external {
        if (block.timestamp < releaseTime) revert ReleaseTimeNotReached();
        uint256 totalBalance = token.balanceOf(address(this));
        for (uint256 i = 0; i < members.length; i++) {
            address member = members[i];
            uint256 amount = (totalBalance * (balances[member])) /
                totalDeposites;
            if (!token.transfer(member, amount)) revert TransferFailed();
            emit DispersedFunds(member, amount);
        }
    }

    // function getTotalDeposits() public view returns (uint256) {
    //     return totalDeposites;
    // }
}
