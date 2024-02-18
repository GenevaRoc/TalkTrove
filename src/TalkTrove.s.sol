//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract TalkTrove {
    /**
     * errors
     */

    ////////////////////////////
    ///// TALK TROVE ERRORS ////
    ///////////////////////////

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
    error TalkTrove_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error TalkTrove__AssetNotSupported();
    error TalkTrove_NoFailedPingsToWithdraw();

    ///////////////////////////////
    //// GROUP SAVING ERRORS /////
    //////////////////////////////
    error TalkTrove_ReleaseTimeMustBeInFuture();
    error TalkTrove_SavingsDoesNotExist();
    error TalkTrove_AlreadyAMember();
    error TalkRove_NotAMemberOfGroupSavings();
    error TalkTrove_SavingsPeriodHasEnded();
    error TalkTrove_OnlyMemberCanReleaseFunds();
    error TalkTrove_SavingsPeriodNotEndedYet();
    error TalkTrove_MustBeRegistered();
    error TalkTrove_GroupDoesNotExist();
    error TalkTrove_SavingsGroupIdAlraedyExists();

    /////////////////////////////////
    //GROUP CHAT ERRORS ////////////
    ////////////////////////////////
    error OnlyGroupOwnerAllowed();
    error UserAlreadyMember();
    error UserNotMember();
    error UserNotAdmin();
    error NoPendingInvitation();
    error NoGroupOwnerChangeToMember();
    error TransferToExistingAdmin();
    error OldAdminCannotBeNewAdmin();
    error MustAssingAdminBeforeOwnerCanLeaveGroup();

    /**
     * Type declarations
     */
    ////////////////////////////////////////
    ////// TALK TROVE TYPE DECLARATIONS ////
    ////////////////////////////////////////

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

    struct Transaction {
        address sender;
        address recipient;
        uint256 amount;
        bytes32 claimCode;
        uint256 timeStamp;
        string description;
        transactionState stateOfTx;
    } //address asset;uint256 timegiven;

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
    mapping(address => string) public addressToUsername; // mapping a user address to username
    mapping(address => FriendRequest[]) public friendRequests; // mapping of user addresses to their friend requests
    mapping(address => PingFriend[]) public pinged; // mapping of user addresses to their piinged requests
    mapping(bytes32 => bool) public usernameTakenOrNot; // mapping to know if a username is already taken
    mapping(address => mapping(address => bool)) public areFriends; // mapping to store friendship status betwween friends
    mapping(address asset => bool supported) private s_supportedAsset;

    ////////////////////////////////////////
    ///// GROUP SAVE TYPE DECLARATION //////
    ////////////////////////////////////////
    struct SavingsGroup {
        address creator;
        uint256 goalAmount;
        uint256 releaseTime;
        uint256 groupId;
        bytes32 groupIdHash;
        string name;
        address[] contributors;
    }

    SavingsGroup[] public savingsGroups;

    mapping(address contributor => mapping(uint256 contribution => uint256 groupId)) contributions;
    mapping(bytes32 => mapping(address => bool)) private members;

    ////////////////////////////////////
    //// GROUP CHAT TPYE DECLARATIONS //
    ////////////////////////////////////
    struct GroupUser {
        uint256 id;
        string username;
        bool isMember;
        bool isAdmin;
    }

    struct Group {
        address owner;
        mapping(address => GroupUser) members;
        string groupName;
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

    /// @notice wrapped matic token and usdt
    address public s_wAvax;
    address public s_usdt;

    ///@notice chainlink price feed addresses
    address public s_avaxPriceFeed;

    /**
     * State Variables
     */
    /////////////////////////////////////
    /// TALK TROVE STATE VARIABLES /////
    ///////////////////////////////////
    Transaction[] public transactions;

    ////////////////////////////////////////
    ///// GROUP SAVE STATE VARIABLE ///////
    ///////////////////////////////////////
    uint256 private constant MINUTES_IN_AN_HOUR = 60;
    uint256 private constant MINUTES_IN_A_DAY = 1440; // 24 hours * 60 minutes
    uint256 private s_theTimeGiven;
    /**
     * Events
     */

    /////////////////////////
    // TALKTROVE EVENTS /////
    /////////////////////////
    event accountCreatedUserRegistered(
        address indexed userAddress,
        string username,
        string additionalInfo
    );
    event RequestSent(
        address indexed sender,
        address indexed receiver,
        uint256 timestamp
    );
    event FriendRequestAccepted(address indexed receiver, uint256 timestamp);
    event FriendRequestDeclined(address indexed sender, uint256 timestamp); //address indexed receiver,
    event FriendRemoved(
        address indexed exfriend,
        address indexed receiver,
        uint256 timestamp
    );
    event pingSent(
        address indexed receiver,
        address indexed sender,
        uint256 amount,
        string indexed description,
        uint256 timestamp
    );
    event pingDeclined(
        address indexed _sender,
        address indexed receiver,
        uint256 timestamp
    );
    event pingRequestDeclined(
        address indexed _sender,
        address indexed receiver,
        uint256 timestamp
    );
    event FundSent(
        address indexed recipient,
        address indexed sender,
        uint256 amount,
        uint256 timestamp,
        string recipientUsername
    );

    ///////////////////////////
    /// GROUP CHAT EVENTS /////
    //////////////////////////
    event GroupCreated(
        uint256 indexed groupId,
        address indexed owner,
        string groupname
    );
    event OwnershipTransferred(
        uint256 indexed groupId,
        address indexed previousOwner,
        address indexed newOwner
    );
    event MemberAdded(uint256 indexed groupId, address indexed member);
    event MemberRemoved(uint256 indexed groupId, address indexed member);
    event MemberInvited(uint256 indexed groupId, address indexed member);
    event MemberJoined(uint256 indexed groupId, address indexed member);
    event InvitationDeclined(address indexed member);
    event AdminAdded(uint256 indexed groupId, address indexed admin);
    event AdminRemoved(uint256 indexed groupId, address indexed admin);
    event MemberLeftGroup(uint256 indexed groupId, address indexed member);
    // emit GroupCreated(groupId, msg.sender, groupname);

    //////////////////////////////
    ///GROUP SAVINGS EVENTS ////
    ///////////////////////////
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
    event FundsReceived(uint256 value);
    event UserJoinedGroup(uint256 indexed _groupId, address indexed sender);

    ///////////////////////////
    ////// Functions /////////
    //////////////////////////
   // constructor(address p)

    function createAccount(
        string memory _username,
        string memory _usersAbout
    ) public returns (bool accountCreated, address id, string memory username) {
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

        users[msg.sender] = User({
            name: _username,
            userInfoOrDescription: _usersAbout,
            id: msg.sender,
            myFriends: emptyFriendsList
        }); // setting the msg.sender as struct User
        User memory newUser = User({
            name: _username,
            userInfoOrDescription: _usersAbout,
            id: msg.sender,
            myFriends: emptyFriendsList
        });
        AllUsers.push(newUser);
        userNameToAddress[_username] = msg.sender;
        addressToUsername[msg.sender] = _username;

        emit accountCreatedUserRegistered(msg.sender, _username, _usersAbout);
        // Return success and account details
        return (true, msg.sender, _username);
    }

    function searchUser(
        string memory usersName
    ) public view returns (string memory, string memory, address) {
        address userAddress = userNameToAddress[usersName];
        if (userAddress == address(0)) {
            revert TalkTrove_UserNotFound();
        }
        return (
            users[userAddress].name,
            users[userAddress].userInfoOrDescription,
            users[userAddress].id
        );
    }

    function sendFriendRequest(
        address _to
    )
        public
        onlyRegisteredUser
        checkIfAlreadyFriends(msg.sender, _to)
        returns (address recipient)
    {
        //returns (address recipient)
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
        FriendRequest memory newFriendRequest = FriendRequest({
            sender: msg.sender,
            reciever: _to,
            State: RequestState.pending
        });
        friendRequests[_to].push(newFriendRequest);

        emit RequestSent(msg.sender, _to, block.timestamp);

        return (_to);
    }

    function acceptFriendRequest() public onlyRegisteredUser {
        for (uint256 i = 0; i < friendRequests[msg.sender].length; i++) {
            if (friendRequests[msg.sender][i].State == RequestState.declined) {
                revert TalkTrove_AlreadyDeclinedThisRequest();
            }
            if (
                friendRequests[msg.sender][i].reciever == msg.sender &&
                friendRequests[msg.sender][i].State == RequestState.pending
            ) {
                // Update the state of the request
                friendRequests[msg.sender][i].State = RequestState.accepted;
                // Update the friendship status to true
                areFriends[msg.sender][
                    friendRequests[msg.sender][i].sender
                ] = true;
                areFriends[friendRequests[msg.sender][i].sender][
                    msg.sender
                ] = true;
                // update the friend list for both the users
                users[msg.sender].myFriends.push(
                    friendRequests[msg.sender][i].sender
                );
                users[friendRequests[msg.sender][i].sender].myFriends.push(
                    msg.sender
                );
                break;
            }
        }
        emit FriendRequestAccepted(msg.sender, block.timestamp);
    }

    function declineFriendRequest() public onlyRegisteredUser {
        for (uint256 i = 0; i < friendRequests[msg.sender].length; i++) {
            if (friendRequests[msg.sender][i].State == RequestState.accepted) {
                revert TalkTrove_AlreadyAcceptedThisRequest();
            }
            if (
                friendRequests[msg.sender][i].reciever == msg.sender &&
                //friendRequests[msg.sender][i].sender == _sender &&
                friendRequests[msg.sender][i].State == RequestState.pending
            ) {
                friendRequests[msg.sender][i].State = RequestState.declined;
                break;
            }
        }
        emit FriendRequestDeclined(msg.sender, block.timestamp);
    }

    function removeFriend(address _exfriend) public onlyRegisteredUser {
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

    // function to send ping to your friend
    function pingMutualFriendForMoney(
        address _to,
        uint256 _amount,
        string memory _description
    ) public onlyRegisteredUser {
        if (!areFriends[msg.sender][_to]) {
            revert TalkTrove_NotFriendsWithThisUser();
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

    function acceptPingAndSend(uint256 _amount) external onlyRegisteredUser {
        for (uint256 i = 0; i < pinged[msg.sender].length; i++) {
            if (pinged[msg.sender][i].stateOfPing == RequestState.declined) {
                revert TalkTrove_AlreadyDeclinedThisRequest();
            }

            if (
                pinged[msg.sender][i].receiver == msg.sender &&
                pinged[msg.sender][i].amount == _amount &&
                pinged[msg.sender][i].stateOfPing == RequestState.pending
            ) {
                pinged[msg.sender][i].stateOfPing = RequestState.accepted;
                payable(pinged[msg.sender][i].sender).transfer(_amount);
                return; // Use return to exit the function after processing the ping
            }
        }
        revert TalkTrove_MustBePingedAmount(); // Revert outside the loop if no valid ping is found
    }

    // function to decline ping from friend
    function declinePing(address _sender) public onlyRegisteredUser {
        for (uint256 i = 0; i < pinged[msg.sender].length; i++) {
            if (pinged[msg.sender][i].stateOfPing == RequestState.accepted) {
                revert TalkTrove_AlreadyAcceptedThisRequest();
            }
            if (
                pinged[msg.sender][i].receiver == msg.sender &&
                pinged[msg.sender][i].sender == _sender &&
                pinged[msg.sender][i].stateOfPing == RequestState.pending &&
                pinged[msg.sender][i].stateOfPing != RequestState.accepted
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
        string memory _desc
    ) external onlyRegisteredUser {
        //address asset
        //uint256 _time
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

        // Check if the claim code has at least 8 characters
        if (bytes(_claimCode).length < 8) {
            revert TalkTrove_ClaimCodeMustBeMoreThan8();
        }

        string memory recipientUsername = getUsernameFromAddress(_recipient);
        // Set the time given
        // s_theTimeGiven = _time * TIME_STAMP_CAL;

        // Get the current timestamp
        uint256 currentTimestamp = block.timestamp;

        // Create a new transaction
        Transaction memory newTransaction = Transaction({
            sender: msg.sender,
            recipient: _recipient,
            amount: _amount,
            claimCode: keccak256(abi.encode(_claimCode)),
            timeStamp: currentTimestamp,
            description: _desc,
            stateOfTx: transactionState.pending
        }); //asset: asset, timegiven: s_theTimeGiven,

        // Add the transaction to the transactions array
        transactions.push(newTransaction);

        emit FundSent(
            _recipient,
            msg.sender,
            _amount,
            block.timestamp,
            recipientUsername
        );
    }

    function claimFunds(uint256 _claimCode) external onlyRegisteredUser {
        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                transactions[i].recipient == msg.sender &&
                keccak256(abi.encode(_claimCode)) ==
                transactions[i].claimCode &&
                transactions[i].stateOfTx == transactionState.pending
            ) {
                // Check if the recipient matches the sender
                if (transactions[i].recipient != msg.sender) {
                    revert TalkTrove_NotTheIntendedRecipient();
                }

                // Check if the claim code matches
                if (
                    transactions[i].claimCode !=
                    keccak256(abi.encode(_claimCode))
                ) {
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
            if (
                transactions[i].sender == msg.sender &&
                transactions[i].stateOfTx == transactionState.pending
            ) {
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

    ////////////////////////////
    ///GROUP SAVE FUNCTIONS ///
    ///////////////////////////
    /**
     * @param _goalAmount: is the set savings goal for the group
     * note: _releaseTimeInDays is in hours,
     */
    function createSavingsGroup(
        uint256 _goalAmount,
        uint256 _releaseTimeInMinutes,
        uint256 _groupId,
        string memory _nameOfGroup
    ) external onlyRegisteredUser {
        bytes32 hashedGroupId = keccak256(abi.encodePacked(_groupId));
        if (_releaseTimeInMinutes == 0) {
            revert TalkTrove_ReleaseTimeMustBeInFuture();
        }
        uint256 releaseTimeInHours = convertMinutesToHours(
            _releaseTimeInMinutes
        ); // Convert minutes to hours
        s_theTimeGiven = block.timestamp + releaseTimeInHours * 1 hours; // Calculate release time in hours
        if (groupExists(hashedGroupId)) {
            revert TalkTrove_SavingsGroupIdAlraedyExists();
        }
        // Create a new savings group
        SavingsGroup memory newGroup;
        newGroup.creator = msg.sender;
        newGroup.goalAmount = _goalAmount;
        newGroup.releaseTime = s_theTimeGiven;
        newGroup.groupId = _groupId;
        newGroup.groupIdHash = hashedGroupId;
        newGroup.name = _nameOfGroup;

        // Add the new group to the savingsGroups array
        savingsGroups.push(newGroup);
        // Update the members mapping with the group ID for the creator
        members[hashedGroupId][msg.sender] = true;
        emit NewSavingsGroup(
            _groupId,
            msg.sender,
            _goalAmount,
            _releaseTimeInMinutes
        );
    }

    function joinSavingsGroup(uint256 _groupId) external onlyRegisteredUser {
        bytes32 hashedGroupId = keccak256(abi.encode(_groupId));
        for (uint256 i = 0; i < savingsGroups.length; i++) {
            if (hashedGroupId == savingsGroups[i].groupIdHash) {
                if (isMember(savingsGroups[i].groupIdHash, msg.sender)) {
                    revert TalkTrove_AlreadyAMember();
                }
                members[savingsGroups[i].groupIdHash][msg.sender] = true;
                emit UserJoinedGroup(_groupId, msg.sender);
                return;
            }
        }
        revert TalkTrove_GroupDoesNotExist();
    }

    function contributeToGroup(
        uint256 _groupId,
        uint256 _contributionAmount
    ) external onlyRegisteredUser {
        bytes32 hashedGroupId = keccak256(abi.encode(_groupId));
        address contributor = msg.sender;
        (uint256 groupIndex, bool groupExistss) = getGroupIndex(hashedGroupId); // Check if the group exists
        if (!groupExistss) {
            revert TalkTrove_GroupDoesNotExist();
        }
        if (block.timestamp >= savingsGroups[groupIndex].releaseTime) {
            revert TalkTrove_SavingsPeriodHasEnded();
        } // Check if the contribution period has not ended

        if (!isMember(hashedGroupId, contributor)) {
            revert TalkRove_NotAMemberOfGroupSavings();
        } // Check if the contributor is a member of the group

        contributions[contributor][_groupId] += _contributionAmount; // Update contributions mapping

        emit Contribution(_groupId, contributor, _contributionAmount); // Emit Contribution event
    }

    function releaseSavings(uint256 _groupId) external onlyRegisteredUser {
        bytes32 hashedGroupId = keccak256(abi.encode(_groupId));
        address contributor = msg.sender;
        (uint256 groupIndex, bool groupExistss) = getGroupIndex(hashedGroupId);

        if (!groupExistss) {
            revert TalkTrove_SavingsDoesNotExist();
        } // Check if the group exists

        if (block.timestamp < savingsGroups[groupIndex].releaseTime) {
            revert TalkTrove_SavingsPeriodNotEndedYet();
        } // Check if the savings period has not ended yet

        if (!isMember(hashedGroupId, contributor)) {
            revert TalkRove_NotAMemberOfGroupSavings();
        } // Check if the contributor is a member of the group

        if (!members[hashedGroupId][contributor]) {
            revert TalkRove_NotAMemberOfGroupSavings();
        } // Check if the only member can release funds

        // Get the contribution amount of the contributor for the specific group
        uint256 contributionAmount = contributions[contributor][_groupId];

        // Check if the contributor has made any contribution to release
        if (contributionAmount == 0) {
            revert TalkTrove_MustBeRegistered();
        }

        // Clear the contribution amount for this contributor
        delete contributions[contributor][_groupId];

        // Transfer the contribution amount back to the contributor
        //payable(contributor).transfer(contributionAmount);
        payable(contributor).transfer(contributionAmount);

        emit FundsReleased(_groupId, contributionAmount);
    }

    /////////////////////////////////
    //// GROUP CHAT FUNCTYIONS ////
    ///////////////////////////////
    function createGroup(
        string calldata username,
        string memory groupname
    ) external onlyRegisteredUser returns (uint256 groupId) {
        groupId = nextGroupId++;
        Group storage group = groups[groupId];
        group.owner = msg.sender;
        group.members[msg.sender] = GroupUser({
            id: groupId,
            username: username,
            isMember: true,
            isAdmin: true
        });
        group.admins.push(msg.sender);
        group.memberList.push(msg.sender);
        group.groupName = groupname;
        emit GroupCreated(groupId, msg.sender, groupname);
        return groupId;
    }

    // Function to invite a new member
    function inviteMember(
        uint256 groupId,
        address newMember
    ) external onlyRegisteredUser checkIfAlreadyFriends(msg.sender, newMember) {
        // Check if the sender is the owner of the group or an admin
        if (
            groups[groupId].owner != msg.sender &&
            !groups[groupId].members[msg.sender].isAdmin
        ) {
            revert UserNotAdmin();
        }

        if (groups[groupId].members[newMember].isMember) {
            revert UserAlreadyMember();
        }
        bool memberisUser = _checkUserIsRegistered(newMember);
        if (!memberisUser) {
            revert TalkTrove_MustBeRegistered();
        }

        invitations[newMember] = Invitation({
            groupId: groupId,
            isPending: true
        });

        emit MemberInvited(groupId, newMember);
    }

    // Function for a user to accept an invitation
    function acceptInvitation() external onlyRegisteredUser {
        if (!invitations[msg.sender].isPending) revert NoPendingInvitation();
        uint256 groupId = invitations[msg.sender].groupId;
        groups[groupId].members[msg.sender] = GroupUser({
            id: groupId,
            username: "", // Username to be set by user
            isMember: true,
            isAdmin: false
        });
        groups[groupId].memberList.push(msg.sender);
        // Update the invitation to mark it as accepted (not pending)
        invitations[msg.sender].isPending = false;

        delete invitations[msg.sender];
        emit MemberJoined(groupId, msg.sender);
    }

    // Function for a user to decline an invitation
    function declineInvitation() external onlyRegisteredUser {
        if (!invitations[msg.sender].isPending) revert NoPendingInvitation();
        // Update the invitation to mark it as accepted (not pending)
        invitations[msg.sender].isPending = false;

        delete invitations[msg.sender];
        emit InvitationDeclined(msg.sender);
    }

    // Function to add a new member
    function addMember(
        uint256 groupId,
        address newMember,
        string calldata username
    ) external onlyRegisteredUser checkIfAlreadyFriends(msg.sender, newMember) {
        if (msg.sender != groups[groupId].owner) revert OnlyGroupOwnerAllowed();
        if (groups[groupId].members[newMember].isMember) {
            revert UserAlreadyMember();
        }
        bool memberisUser = _checkUserIsRegistered(newMember);
        if (!memberisUser) {
            revert TalkTrove_MustBeRegistered();
        }

        groups[groupId].members[newMember] = GroupUser({
            id: groupId,
            username: username,
            isMember: true,
            isAdmin: false
        });
        groups[groupId].memberList.push(newMember);

        emit MemberAdded(groupId, newMember);
    }

    function adminLeaveGroup(uint256 groupId) external onlyRegisteredUser {
        if (!groups[groupId].members[msg.sender].isMember) {
            revert UserNotMember();
        }

        if (msg.sender == groups[groupId].owner) {
            address newOwner = address(0);

            // Set leaving owner's admin status to false
            groups[groupId].members[msg.sender].isAdmin = false;

            // Filter admins whose isAdmin status is true
            address[] memory activeAdmins = new address[](
                groups[groupId].admins.length
            );
            uint256 activeAdminsCount = 0;
            for (uint256 i = 0; i < groups[groupId].admins.length; i++) {
                if (
                    groups[groupId].members[groups[groupId].admins[i]].isAdmin
                ) {
                    activeAdmins[activeAdminsCount] = groups[groupId].admins[i];
                    activeAdminsCount++;
                }
            }

            // Check if there are any active admins left
            if (activeAdminsCount > 0) {
                // Randomly select new owner from active admins
                uint256 randomIndex = uint256(
                    keccak256(
                        abi.encodePacked(
                            block.timestamp,
                            blockhash(block.number - 1)
                        )
                    )
                ) % activeAdminsCount;
                newOwner = activeAdmins[randomIndex];
            } else {
                // No active admins left, revert
                groups[groupId].members[msg.sender].isAdmin = true; // Revert leaving owner's admin status
                revert("Must assign admin before owner can leave group");
            }

            // Transfer ownership to the new owner
            groups[groupId].owner = newOwner;
            groups[groupId].members[newOwner].isAdmin = true; // Ensure the new owner is an admin

            emit OwnershipTransferred(groupId, msg.sender, newOwner);
        }

        // Remove member from group
        removeMemberFromGroup(groupId, msg.sender);
    }

    // Function to assign admin role
    function assignAdmin(
        uint256 groupId,
        address member
    ) external onlyRegisteredUser {
        if (msg.sender != groups[groupId].owner) revert OnlyGroupOwnerAllowed();
        if (!groups[groupId].members[member].isMember) revert UserNotMember();
        if (groups[groupId].members[member].isAdmin) {
            revert TransferToExistingAdmin();
        }
        bool isUser = _checkUserIsRegistered(member);
        if (!isUser) {
            revert TalkTrove_MustBeRegistered();
        }

        groups[groupId].members[member].isAdmin = true;
        groups[groupId].admins.push(member);

        emit AdminAdded(groupId, member);
    }

    // Function to remove a member
    function removeMember(
        uint256 groupId,
        address member
    ) external onlyRegisteredUser {
        if (
            msg.sender != groups[groupId].owner &&
            !groups[groupId].members[msg.sender].isAdmin
        ) {
            revert OnlyGroupOwnerAllowed();
        }
        bool memberisUser = _checkUserIsRegistered(member);
        if (!memberisUser) {
            revert TalkTrove_MustBeRegistered();
        }
        if (!groups[groupId].members[member].isMember) revert UserNotMember();

        removeMemberFromGroup(groupId, member);
    }

    // Function for a user to leave a group
    function userLeaveGroup(uint256 groupId) external onlyRegisteredUser {
        if (!groups[groupId].members[msg.sender].isMember) {
            revert UserNotMember();
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
            group.memberList[indexToRemove] = group.memberList[
                group.memberList.length - 1
            ];
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
                groups[groupId].memberList[i] = groups[groupId].memberList[
                    groups[groupId].memberList.length - 1
                ];
                groups[groupId].memberList.pop();
                break;
            }
        }
        emit MemberRemoved(groupId, member);
    }

    //////////////////////////
    //// HELPER FUNCTIONS ////
    //////////////////////////

    /**
     * for group savings.
     */
    function groupExists(bytes32 _hashedGroupId) private view returns (bool) {
        for (uint256 i = 0; i < savingsGroups.length; i++) {
            if (
                keccak256(abi.encodePacked(savingsGroups[i].groupId)) ==
                _hashedGroupId
            ) {
                return true;
            }
        }
        return false;
    }

    function getGroupIndex(
        bytes32 _hashedGroupId
    ) internal view returns (uint256, bool) {
        for (uint256 i = 0; i < savingsGroups.length; i++) {
            if (_hashedGroupId == savingsGroups[i].groupIdHash) {
                return (i, true); // Return the index and true if the group exists
            }
        }
        return (0, false); // Return 0 and false if the group doesn't exist
    }

    function isMember(
        bytes32 _hashedGroupId,
        address _member
    ) public view returns (bool) {
        return members[_hashedGroupId][_member];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getSavingsGroups() external view returns (SavingsGroup memory) {
        return savingsGroups[0];
    }

    /**
     * for talk trove
     */
    function _checkUserIsRegistered(address _user) public view returns (bool) {
        for (uint256 i = 0; i < AllUsers.length; i++) {
            if (_user == AllUsers[i].id) {
                return true;
            }
        }
        return false;
    }

    function _checkIfAlreadyFriends(
        address _user,
        address _friend
    ) public view returns (bool) {
        return areFriends[_user][_friend];
    }

    function getUsernameFromAddress(
        address _address
    ) internal view returns (string memory) {
        return addressToUsername[_address];
    }

    modifier checkAssetSupport(address asset) {
        if (!s_supportedAsset[asset]) {
            revert TalkTrove__AssetNotSupported();
        }
        _;
    }

    modifier onlyRegisteredUser() {
        if (!_checkUserIsRegistered(msg.sender)) {
            revert TalkTrove_YoureNotRegistered();
        }
        _;
    }

    modifier checkIfAlreadyFriends(address _user, address _friend) {
        require(areFriends[_user][_friend], "Not friends");
        _;
    }

    // Function to receive Ether
    receive() external payable {
        emit FundsReceived(msg.value);
    }

    /**
     * this code calculates the time lock period for a group savong in days
     */
    function convertMinutesToHours(
        uint256 minutesValue
    ) public pure returns (uint256) {
        return minutesValue / MINUTES_IN_AN_HOUR;
    } // function used

    function convertMinutesToDays(
        uint256 minutesValue
    ) public pure returns (uint256) {
        return minutesValue / MINUTES_IN_A_DAY;
    } // helper convert function

    function convertSavingsLockTimeToMinutes(
        uint256 daysValue
    ) public pure returns (uint256) {
        return daysValue * MINUTES_IN_A_DAY;
    } // helper convert function
}
