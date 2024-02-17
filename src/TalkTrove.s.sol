//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {GroupContract} from "./TalkTroveGroupC.s.sol";
import {GroupSavings} from "./TalkTroveGroupSaving.s.sol";

// OpenZeppelin Imports
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TalkTrove {
    /**
     * errors
     */
    error TalkTrove_NameCannotBeEmpty();
    error TalkTrove_UserAlreadyRegistered();
    error TalkTrove_NameAlreadyTaken();
    error TalkTrove_UserNotFound();
    error TalkTrove_YoureNotRegistered();
    error TalkTrove_FriendIsNotRegistered();
    error TalkTrove_YouCannotSendARequestToYourSelf();
    error TalkTrove_AlreadyFriendsWithThisUser();
    error TalkTrove_AlreadyDeclinedThisRequest();
    error TalkTrove_AlreadyAcceptedThisRequest();
    error TalkTrove_NotFriendsWithThisUser();
    error TalkTrove_MustBeMoreThanZero();
    error TalkTrove_PingRequestHasAlreadyCompleted();
    error TalkTrove_MustBePingedAmount();
    error TalkTrove_NotEnoughAmountSent();
    error TalkTrove_AddressDoesNotExist();
    error TalkTrove_ClaimCodeMustBeMoreThan8();
    error TalkTrove_NotTheIntendedRecipient();
    error TalkTrove_IncorrectClaimCode();
    error TalkTrove_NoLongerPending();
    error TalkTrove_NotTheInitialSender();

    /**
     * Type declarations
     */
    struct User {
        string name;
        string userInfoOrDescription;
        address id;
        address[] myFriends;
    }

    User[] public AllUsers;

    struct FriendRequest {
        address sender;
        address reciever;
        RequestState State;
    }

    struct PingFriend {
        address sender;
        address receiver;
        uint256 amount;
        uint256 timestamp;
        string description;
        RequestState stateOfPing;
    }
    //PingFriend[] public pinged;

    struct Transaction {
        address sender;
        address recipient;
        uint256 amount;
        bytes32 claimCode;
        uint256 timegiven;
        uint256 timeStamp;
        string description;
        transactionState stateOfTx;
    }

    enum RequestState {
        pending,
        accepted,
        declined
    }
    enum transactionState {
        pending,
        claimed,
        reclaimed
    }

    mapping(address => User) public users; // mapping user address to store users accounts
    mapping(string => address) public userNameToAddress; // mapping a users Username to an address
    mapping(address => FriendRequest[]) public friendRequests; // mapping of user addresses to their friend requests
    mapping(address => PingFriend[]) public pinged; // mapping of user addresses to their piinged requests
    // mapping(address => Transaction[]) public transactions; // mapping of user addresses to their piinged requests
    mapping(bytes32 => bool) public usernameTakenOrNot; // mapping to know if a username is already taken
    mapping(address => mapping(address => bool)) public areFriends; // mapping to store friendship status betwween friends

    GroupContract private immutable i_TTGC;
    GroupSavings private immutable i_TTGS;

    /**
     * State Variables
     */
    Transaction[] public transactions;
    uint256 private s_theTimeGiven;
    uint256 private constant TIME_STAMP_CAL = 60;

    /**
     * Events
     */
    event accountCreatedUserRegistered(address indexed userAddress, string username, string additionalInfo);
    event RequestSent(address indexed sender, address indexed receiver, uint256 timestamp);
    event FriendRequestAccepted(address indexed receiver, uint256 timestamp);
    event FriendRequestDeclined(address indexed sender, address indexed receiver, uint256 timestamp);
    event FriendRemoved(address indexed exfriend, address indexed receiver, uint256 timestamp);
    event pingSent(
        address indexed receiver, address indexed sender, uint256 amount, string indexed description, uint256 timestamp
    );
    event pingDeclined(address indexed _sender, address indexed receiver, uint256 timestamp);
    event pingRequestDeclined(address indexed _sender, address indexed receiver, uint256 timestamp);
    event FundSent(address indexed recipient, address indexed sender, uint256 amount, uint256 timestamp);

    ///////////////////////////
    ////// Functions /////////
    //////////////////////////

    function createAccount(string memory _username, string memory _usersAbout)
        public
        returns (bool accountCreated, address id, string memory username)
    {
        if (bytes(_username).length <= 0) {
            revert TalkTrove_NameCannotBeEmpty();
        }

        if (bytes(users[msg.sender].name).length != 0) {
            revert TalkTrove_UserAlreadyRegistered();
        }
        bytes32 UserName = keccak256(abi.encode(_username));
        // Check if the name already exists
        if (usernameTakenOrNot[UserName]) {
            revert TalkTrove_NameAlreadyTaken();
        }
        usernameTakenOrNot[UserName] = true;

        // Initialize the friends array for the new user
        address[] memory emptyFriendsList;

        users[msg.sender] =
            User({name: _username, userInfoOrDescription: _usersAbout, id: msg.sender, myFriends: emptyFriendsList}); // setting the msg.sender as struct User
        User memory newUser =
            User({name: _username, userInfoOrDescription: _usersAbout, id: msg.sender, myFriends: emptyFriendsList});
        AllUsers.push(newUser);
        userNameToAddress[_username] = msg.sender;

        emit accountCreatedUserRegistered(msg.sender, _username, _usersAbout);
        // Return success and account details
        return (true, msg.sender, _username);
    }

    function searchUser(string memory usersName) public view returns (string memory, string memory, address) {
        address userAddress = userNameToAddress[usersName];
        if (userAddress == address(0)) {
            revert TalkTrove_UserNotFound();
        }
        return (users[userAddress].name, users[userAddress].userInfoOrDescription, users[userAddress].id);
    }

    function sendFriendRequest(address _to) public returns (address recipient) {
        // Check if the sender is a registered user
        if (!_checkUserIsRegistered(msg.sender)) {
            revert TalkTrove_YoureNotRegistered();
        }

        // Check if the recipient is a registered user
        if (!_checkUserIsRegistered(_to)) {
            revert TalkTrove_FriendIsNotRegistered();
        }

        // Check if the sender is not the same as the recipient
        if (_to == msg.sender) {
            revert TalkTrove_YouCannotSendARequestToYourSelf();
        }

        // Check if the users are already friends
        if (areFriends[msg.sender][_to]) {
            revert TalkTrove_AlreadyFriendsWithThisUser();
        }

        // Create a new friend request
        FriendRequest memory newFriendRequest =
            FriendRequest({sender: msg.sender, reciever: _to, State: RequestState.pending});
        friendRequests[_to].push(newFriendRequest);

        emit RequestSent(msg.sender, _to, block.timestamp);

        return (_to);
    }

    function acceptFriendRequest() public {
        for (uint256 i = 0; i < friendRequests[msg.sender].length; i++) {
            if (friendRequests[msg.sender][i].State == RequestState.declined) {
                revert TalkTrove_AlreadyDeclinedThisRequest();
            }
            if (
                friendRequests[msg.sender][i].reciever == msg.sender
                    && friendRequests[msg.sender][i].State == RequestState.pending
            ) {
                // Update the state of the request
                friendRequests[msg.sender][i].State = RequestState.accepted;
                // Update the friendship status to true
                areFriends[msg.sender][friendRequests[msg.sender][i].sender] = true;
                areFriends[friendRequests[msg.sender][i].sender][msg.sender] = true;
                // update the friend list for both the users
                users[msg.sender].myFriends.push(friendRequests[msg.sender][i].sender);
                users[friendRequests[msg.sender][i].sender].myFriends.push(msg.sender);
                break;
            }
        }
        emit FriendRequestAccepted(msg.sender, block.timestamp);
    }

    function declineFriendRequest(address _sender) public {
        for (uint256 i = 0; i < friendRequests[msg.sender].length; i++) {
            if (friendRequests[msg.sender][i].State == RequestState.accepted) {
                revert TalkTrove_AlreadyAcceptedThisRequest();
            }
            if (
                friendRequests[msg.sender][i].reciever == msg.sender && friendRequests[msg.sender][i].sender == _sender
                    && friendRequests[msg.sender][i].State == RequestState.pending
            ) {
                friendRequests[msg.sender][i].State = RequestState.declined;
                break;
            }
        }
        emit FriendRequestDeclined(_sender, msg.sender, block.timestamp);
    }

    function removeFriend(address _exfriend) public {
        bool condition = _checkIfAlreadyFriends(msg.sender, _exfriend);
        if (!condition) {
            revert TalkTrove_NotFriendsWithThisUser();
        }

        if (users[msg.sender].id == address(0)) {
            revert TalkTrove_YoureNotRegistered();
        }

        if (users[_exfriend].id == address(0)) {
            revert TalkTrove_FriendIsNotRegistered();
        }

        // Update the friendship status for both users to false
        areFriends[msg.sender][_exfriend] = false;
        areFriends[_exfriend][msg.sender] = false;
        emit FriendRemoved(_exfriend, msg.sender, block.timestamp);
    }

    function pingMutualFriendForMoney(address _to, uint256 _amount, string memory _description) public {
        if (!areFriends[msg.sender][_to]) {
            revert TalkTrove_NotFriendsWithThisUser();
        }

        bool condition = _checkUserIsRegistered(msg.sender);
        if (!condition) {
            revert TalkTrove_YoureNotRegistered();
        }

        // Check if the friend is a registered user
        bool condition2 = _checkUserIsRegistered(_to);
        if (!condition2) {
            revert TalkTrove_FriendIsNotRegistered();
        }

        // Check if the sender is not the same as the recipient
        if (_to == msg.sender) {
            revert TalkTrove_YouCannotSendARequestToYourSelf();
        }

        // Check if the amount is greater than zero
        if (_amount == 0) {
            revert TalkTrove_MustBeMoreThanZero();
        }

        uint256 currentTimestamp = block.timestamp;
        PingFriend memory newPing = PingFriend({
            sender: msg.sender,
            receiver: _to,
            amount: _amount,
            timestamp: currentTimestamp,
            description: _description,
            stateOfPing: RequestState.pending
        });
        pinged[_to].push(newPing);

        emit pingSent(_to, msg.sender, _amount, _description, block.timestamp);
    }

    function acceptPingAndSend(uint256 _amount) public payable {
        for (uint256 i = 0; i < pinged[msg.sender].length; i++) {
            if (pinged[msg.sender][i].stateOfPing == RequestState.declined) {
                revert TalkTrove_AlreadyDeclinedThisRequest();
            }

            if (
                pinged[msg.sender][i].receiver == msg.sender && pinged[msg.sender][i].amount == _amount
                    && pinged[msg.sender][i].stateOfPing == RequestState.pending
            ) {
                // Check if the ping has already been completed
                if (pinged[msg.sender][i].stateOfPing != RequestState.pending) {
                    revert TalkTrove_PingRequestHasAlreadyCompleted();
                }

                if (pinged[msg.sender][i].amount != _amount) {
                    revert TalkTrove_MustBePingedAmount();
                }

                // Check if the sent value matches the expected amount
                if (msg.value != _amount) {
                    revert TalkTrove_NotEnoughAmountSent();
                }

                // Update the state of the ping request to "accepted"
                pinged[msg.sender][i].stateOfPing = RequestState.accepted;

                // Transfer the amount to the sender
                payable(pinged[msg.sender][i].receiver).transfer(_amount);

                // Delete the ping request
                delete (pinged[msg.sender][i]);
                break;
            }
        }
    }

    function declinePing(address _sender) public {
        for (uint256 i = 0; i < pinged[msg.sender].length; i++) {
            if (pinged[msg.sender][i].stateOfPing != RequestState.accepted) {
                revert TalkTrove_AlreadyAcceptedThisRequest();
            }
            if (
                pinged[msg.sender][i].receiver == msg.sender && pinged[msg.sender][i].sender == _sender
                    && pinged[msg.sender][i].stateOfPing == RequestState.pending
                    && pinged[msg.sender][i].stateOfPing != RequestState.accepted
            ) {
                // Update the state of the ping request to "declined"
                pinged[msg.sender][i].stateOfPing = RequestState.declined;
                break;
            }
        }
        emit pingRequestDeclined(_sender, msg.sender, block.timestamp);
    }

    function sendFundsUsingAddr(
        address _recipient,
        uint256 _amount,
        string memory _claimCode,
        string memory _desc,
        uint256 _time
    ) public payable {
        // Check if the recipient is not the sender
        if (_recipient == msg.sender) {
            revert TalkTrove_YouCannotSendARequestToYourSelf();
        }

        // Check if the sender is not the contract itself
        if (msg.sender == address(this)) {
            revert();
        }

        // Check if the recipient address is not zero
        if (_recipient == address(0)) {
            revert TalkTrove_AddressDoesNotExist();
        }

        // Check if the amount is greater than zero
        if (_amount == 0) {
            revert TalkTrove_MustBeMoreThanZero();
        }

        // Check if the sent value matches the specified amount
        if (msg.value != _amount) {
            revert TalkTrove_NotEnoughAmountSent();
        }

        // Check if the claim code has at least 8 characters
        if (bytes(_claimCode).length < 8) {
            revert TalkTrove_ClaimCodeMustBeMoreThan8();
        }

        // Check if the sender is a registered user
        bool condition = _checkUserIsRegistered(msg.sender);
        if (!condition) {
            revert TalkTrove_YoureNotRegistered();
        }

        // Set the time given
        s_theTimeGiven = _time * TIME_STAMP_CAL;

        // Get the current timestamp
        uint256 currentTimestamp = block.timestamp;

        // Create a new transaction
        Transaction memory newTransaction = Transaction({
            sender: msg.sender,
            recipient: _recipient,
            amount: _amount,
            claimCode: keccak256(abi.encode(_claimCode)),
            timegiven: s_theTimeGiven,
            timeStamp: currentTimestamp,
            description: _desc,
            stateOfTx: transactionState.pending
        });

        // Add the transaction to the transactions array
        transactions.push(newTransaction);

        emit FundSent(_recipient, msg.sender, _amount, block.timestamp);
    }

    function claimFunds(uint256 _claimCode) external {
        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                transactions[i].recipient == msg.sender
                    && keccak256(abi.encode(_claimCode)) == transactions[i].claimCode
                    && transactions[i].stateOfTx == transactionState.pending
            ) {
                // Check if the recipient matches the sender
                if (transactions[i].recipient != msg.sender) {
                    revert TalkTrove_NotTheIntendedRecipient();
                }

                // Check if the claim code matches
                if (transactions[i].claimCode != keccak256(abi.encode(_claimCode))) {
                    revert TalkTrove_IncorrectClaimCode();
                }

                // Check if the transaction state is pending
                if (transactions[i].stateOfTx != transactionState.pending) {
                    revert TalkTrove_NoLongerPending();
                }

                // Check if the amount is greater than zero
                if (transactions[i].amount == 0) {
                    revert TalkTrove_MustBeMoreThanZero();
                }

                uint256 amountToTransfer = transactions[i].amount;
                // Transfer the amount to the recipient
                payable(msg.sender).transfer(amountToTransfer);
                // Update the state to claimed
                transactions[i].stateOfTx = transactionState.claimed;
                // Additional actions after transferring funds
                delete (transactions[i]);
            }
        }
    }

    function ReclaimFunds() public {
        for (uint256 i = 0; i < transactions.length; i++) {
            // Transaction storage transaction = transactions[i];
            if (transactions[i].sender == msg.sender && transactions[i].stateOfTx == transactionState.pending) {
                if (transactions[i].sender != msg.sender) {
                    revert TalkTrove_NotTheInitialSender();
                }
                if (transactions[i].amount < 0) {
                    revert TalkTrove_MustBeMoreThanZero();
                }
                // Update the state to reclaimed
                transactions[i].stateOfTx = transactionState.reclaimed;

                uint256 amountToTransfer = transactions[i].amount;
                payable(msg.sender).transfer(amountToTransfer);

                delete (transactions[i]);
            }
        }
    }

    function checkUpKeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        for (uint256 i = 0; i < transactions.length; i++) {
            bool timeForRevert = (block.timestamp - transactions[i].timeStamp) >= transactions[i].timegiven;
            bool isNotYetClaimed = (transactions[i].stateOfTx != transactionState.claimed);
            bool isNotYetRelaimed = (transactions[i].stateOfTx != transactionState.reclaimed);
            bool hasBalance = address(this).balance > 0;
            bool etherWasSent = transactions[i].amount > 0;
            //performData = checkData;
            upkeepNeeded = (timeForRevert && isNotYetClaimed && hasBalance && isNotYetRelaimed && etherWasSent);
            if (upkeepNeeded) {
                return (true, "0x0");
            }
        }
        return (false, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/ ) external {
        (bool upKeepNeeded,) = checkUpKeep("");
        require(upKeepNeeded, "no upkeep needed");
        ReclaimFunds();
        //performData;
    }

    /////////////////
    /// GETTERS /////
    ////////////////

    function _checkUserIsRegistered(address _user) public view returns (bool) {
        for (uint256 i = 0; i < AllUsers.length; i++) {
            if (_user == AllUsers[i].id) {
                return true;
            }
        }
        return false;
    }

    function _checkIfAlreadyFriends(address _user, address _friend) public view returns (bool) {
        return areFriends[_user][_friend];
    }
}
