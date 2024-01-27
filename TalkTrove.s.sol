//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract TalkTrove {
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

    Transaction[] public transactions;
    uint256 private s_theTimeGiven;
    uint256 private constant TIME_STAMP_CAL = 60;

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

    // Event to log user registration
    event accountCreatedUserRegistered(address indexed userAddress, string username, string additionalInfo);
    event RequestSent(address indexed sender, address indexed receiver, uint256 timestamp);
    event FriendRequestAccepted(address indexed sender, address indexed receiver, uint256 timestamp);
    event FriendRequestDeclined(address indexed sender, address indexed receiver, uint256 timestamp);
    event FriendRemoved(address indexed exfriend, address indexed receiver, uint256 timestamp);
    event pingSent(
        address indexed receiver, address indexed sender, uint256 amount, string indexed description, uint256 timestamp
    );
    event pingDeclined(address indexed _sender, address indexed receiver, uint256 timestamp);
    event pingRequestDeclined(address indexed _sender, address indexed receiver, uint256 timestamp);
    event FundSent(address indexed recipient, address indexed sender, uint256 amount, uint256 timestamp);

    function createAccount(string memory _username, string memory _usersAbout) public {
        require(bytes(_username).length > 0, "Name cannot be empty");
        require(bytes(users[msg.sender].name).length == 0, "User already registered");
        bytes32 UserName = keccak256(abi.encode(_username));
        // Check if the name already exists
        require(!usernameTakenOrNot[UserName], "Name already exists");
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
    }

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

    function searchUser(string memory usersName) public view returns (string memory, string memory, address) {
        address userAddress = userNameToAddress[usersName];
        require(userAddress != address(0), "User not found");
        return (users[userAddress].name, users[userAddress].userInfoOrDescription, users[userAddress].id);
    }

    function sendFriendRequest(address _to) public {
        // check to see if this user is registered
        bool condition = _checkUserIsRegistered(msg.sender);
        require(condition, "You have to be a registered user first");
        // check to see if the friend is a registered user
        bool condition2 = _checkUserIsRegistered(_to);
        require(condition2, "friend has to be a registered user first");
        require(_to != msg.sender, "you cannot send request to yourself");
        // check if two users are already friend
        require(!areFriends[msg.sender][_to], "already friends with this user");
        FriendRequest memory newFriendRequest =
            FriendRequest({sender: msg.sender, reciever: _to, State: RequestState.pending});
        friendRequests[_to].push(newFriendRequest);
        emit RequestSent(msg.sender, _to, block.timestamp);
    }

    function acceptFriendRequest(address _sender) public {
        for (uint256 i = 0; i < friendRequests[msg.sender].length; i++) {
            require(friendRequests[msg.sender][i].State != RequestState.declined, "already declined request");
            if (
                friendRequests[msg.sender][i].reciever == msg.sender && friendRequests[msg.sender][i].sender == _sender
                    && friendRequests[msg.sender][i].State == RequestState.pending
            ) {
                friendRequests[msg.sender][i].State = RequestState.accepted;
                // Update the friendship status to true
                areFriends[msg.sender][_sender] = true;
                areFriends[_sender][msg.sender] = true;
                // update the friend list for both the users
                users[msg.sender].myFriends.push(_sender);
                users[_sender].myFriends.push(msg.sender);
                break;
            }
        }
        emit FriendRequestAccepted(_sender, msg.sender, block.timestamp);
    }

    function declineFriendRequest(address _sender) public {
        for (uint256 i = 0; i < friendRequests[msg.sender].length; i++) {
            require(friendRequests[msg.sender][i].State != RequestState.accepted, "already accepted request");
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
        require(condition, "this user is not friends with you");
        require(users[msg.sender].id != address(0), "user does not exist");
        require(users[_exfriend].id != address(0), "friend does not exist");
        //require(areFriends[msg.sender][_exfriend], "")
        // Update the friendship status to false
        areFriends[msg.sender][_exfriend] = false;
        areFriends[_exfriend][msg.sender] = false;
        emit FriendRemoved(_exfriend, msg.sender, block.timestamp);
    }

    function pingMutualFriendForMoney(address _to, uint256 _amount, string memory _description) public {
        require(areFriends[msg.sender][_to] == true, "can't send ping if you are not friends");
        bool condition = _checkUserIsRegistered(msg.sender);
        require(condition, "You have to be a registered user first");
        // check to see if the friend is a registered user
        bool condition2 = _checkUserIsRegistered(_to);
        require(condition2, "friend has to be a registered user first");
        require(_to != msg.sender, "you cannot send request to yourself");
        require(_amount > 0, "can't ping a zero amount");
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

    function acceptPingAndSend(address payable _sender, uint256 _amount) public payable {
        for (uint256 i = 0; i < pinged[msg.sender].length; i++) {
            require(pinged[msg.sender][i].stateOfPing != RequestState.declined, "this has already been declined");
            if (
                pinged[msg.sender][i].receiver == msg.sender && pinged[msg.sender][i].sender == _sender
                    && pinged[msg.sender][i].amount == _amount && pinged[msg.sender][i].stateOfPing == RequestState.pending
                    && pinged[msg.sender][i].stateOfPing != RequestState.declined
            ) {
                require(pinged[msg.sender][i].stateOfPing == RequestState.pending, "ping had already been completed");
                require(msg.value == _amount, "Insufficient amount sent");

                // Update the state of the ping request to "accepted"
                pinged[msg.sender][i].stateOfPing = RequestState.accepted;
                //uint amountToTransfer = _amount;
                payable(_sender).transfer(_amount);

                delete (pinged[msg.sender][i]);
                break;
            }
        }
    }

    function declinePing(address _sender) public {
        for (uint256 i = 0; i < pinged[msg.sender].length; i++) {
            require(pinged[msg.sender][i].stateOfPing != RequestState.accepted, "this has already been accepted");
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
        require(_recipient != msg.sender, "can't send to yourself");
        require(msg.sender != address(this));
        require(_recipient != address(0), "can't send to zero address");
        require(_amount > 0, "Invalid amount of Ether sent");
        require(msg.value == _amount, "Sent Ether doesn't match the specified amount");
        require(bytes(_claimCode).length >= 8, "claim code must be 8 characters");
        bytes32 claimCodeHash = keccak256(abi.encode(_claimCode));

        bool condition = _checkUserIsRegistered(msg.sender);
        require(condition, "You have to be a registered user first");
        s_theTimeGiven = _time * TIME_STAMP_CAL;
        // Get the current timestamp
        uint256 currentTimestamp = block.timestamp;
        Transaction memory newTransaction = Transaction({
            sender: msg.sender,
            recipient: _recipient,
            amount: _amount,
            claimCode: claimCodeHash,
            timegiven: s_theTimeGiven,
            timeStamp: currentTimestamp,
            description: _desc,
            stateOfTx: transactionState.pending
        });
        transactions.push(newTransaction);
        emit FundSent(_recipient, msg.sender, _amount, block.timestamp);
    }

    function claimFunds(uint256 _claimCode) external {
        for (uint256 i = 0; i < transactions.length; i++) {
            // Transaction storage transaction = transactions[i];
            if (
                transactions[i].recipient == msg.sender
                    && keccak256(abi.encode(_claimCode)) == transactions[i].claimCode
                    && transactions[i].stateOfTx == transactionState.pending
            ) {
                require(transactions[i].recipient == msg.sender, "not the intended recipient");
                require(transactions[i].claimCode == keccak256(abi.encode(_claimCode)), "incorrect claim code");
                require(transactions[i].stateOfTx == transactionState.pending);
                require(transactions[i].amount > 0);

                uint256 amountToTransfer = transactions[i].amount;
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
            if (transactions[i].sender == msg.sender) {
                require(transactions[i].sender == msg.sender, "not the initial sender of this fund");
                require(transactions[i].amount > 0);

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
            bool hasBalance = address(this).balance > 0;
            bool etherWasSent = transactions[i].amount > 0;
            //performData = checkData;
            upkeepNeeded = (timeForRevert && isNotYetClaimed && hasBalance && etherWasSent);
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
}

