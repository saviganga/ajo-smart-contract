// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

contract Esusu {


    // VARIABLES

    // declare the admin
    address payable esusuAdmin;

    // track the groupcount and userCount
    uint public groupCount = 0;
    uint public userCount = 0;

    // create a list of groups and users
    Group[]public groupList;
    EsusuUser[] public userList;

    // create the admin (owner)
    // struct AdminOwner {
    //     address payable adminAddress;
    //     uint adminBalance;
    // }

    // create a user (so you cn have a central wllet where funds from all your goups can be withdrawn from)
    struct EsusuUser {
        address payable userAddress;
        uint userBalance;
    }

    // create a groupMember
    struct GroupMember {
        address payable userAddress;
        uint nextPaymentDate;
        uint nextPaymentAmount;
        uint lastPaymentAmount;
        uint lastPaymentDate;
        uint[] completedDonationRounds;
    }

    // create a group
    struct Group {
        uint id;
        string groupName;
        uint groupBuyInAmount;
        address payable groupCoordinator;
        uint groupBalance;
        uint groupActivationTime;
        uint numMembers;
        uint adminbalance;
    
    }

    // create a donation
    struct GroupDonation {
        Group group;
        uint donationRound;
        uint donationStartTime;
        uint donationEndTime;
        uint latePaymentStartTime;
        uint latePaymentEndTime;
    }



    // CONSTRUCTOR WITH MAPPING OF ADDRESS TO ADMIN

    // mapping between groupId and donation rounds
    mapping (uint => GroupDonation[]) groupDonations;

    // create a mapping between groups and groupmembers (name)
    mapping (string => GroupMember[]) groupinfo;

    // create a mapping between groups and groupmembers (id)
    mapping (uint => GroupMember[]) groupinfo_i;

    // mapping between group id and list of groupmembers (map with address of member for each group)
    mapping (uint => GroupMember[]) groupMemberDict;

    // mapping between group index and group
    mapping (uint => Group) groupDict;

    // mapping between address and groupmembers
    mapping (address => Group[]) userGroups;

    // mapping between user profile and user address
    mapping (address => EsusuUser) userProfile;


    // EVENTS 
    event createGroupEvent(address _groupCoordinator, Group _group, uint cbalance);
    event newGroupMemberEvent(address _groupMember, Group _group, uint cbalance);
    event groupActivationEvent(Group _group, uint _groupActivationTime, uint cbalance);
    event payGroupMemberEvent(Group _group, GroupMember _groupMember, uint _paymentAmount, uint _paymentTime, uint cbalance);
    event userWithdrawalEvent(EsusuUser _user, uint _withdrawalAmount, uint _withdrawalTime, uint cbalance);
    event createUserProfileEvent(address _userAddress, EsusuUser _userProfile, uint _userCreationTime, uint cbalance);
    event lastGroupPaymentEvent(Group _group, GroupMember _groupMember, uint _paymentAmount, uint _paymentTime, uint cbalance);


    constructor() {
        esusuAdmin = payable(msg.sender);
    }

    // FUNCTIONS

    // function to get a user profile
    function getUserProfile() public view returns(EsusuUser memory) {
        require(userProfile[msg.sender].userAddress == msg.sender, "Create an EsusuUser account to view profile");
        
        EsusuUser storage userprofile = userProfile[msg.sender];
        return userprofile;
    }




    // function to get a user's groups
    function getUserGroups() public view returns(Group[] memory) {
        require(userProfile[msg.sender].userAddress == msg.sender, "Create an EsusuUser account to access this functionality");

        Group[] storage usergroups = userGroups[msg.sender];
        return usergroups;
    }




    // function to create a user profile
    function createUserProfile() public {

        require(userProfile[msg.sender].userAddress != msg.sender, "You are already a user");

        EsusuUser memory userprofile = EsusuUser(payable(msg.sender), 0);
        userList.push(userprofile);
        userCount += 1;
        userProfile[msg.sender] = userprofile;

        // subscribe to events
        emit createUserProfileEvent(msg.sender, userprofile, block.timestamp, address(this).balance);
    }


    // function to create a group
    function createGroup(string memory groupName, uint groupBuyInAmount, uint numGroupMembers) payable public {

        // validate (...??how do i get buyinamount == msg.value??)
        // require(msg.value == groupBuyInAmount, "error" );
        // require(groupBuyInAmount >= 5, "error! group buyin amount must be greater than 5 eher");
        require(msg.value == groupBuyInAmount * (1 ether), "error! payment value must be group buyin mount" );
        require(userProfile[msg.sender].userAddress == msg.sender, "Create an EsusuUser account to create a group");
        
        // create a group by paying in
        if(!payable(msg.sender).send(groupBuyInAmount)) {
            revert("Unable to transfer buyIn funds");
        }

        // increase group count
        groupCount += 1;

        // create a groupMember object
        uint[] memory groupMemberDonations;
        GroupMember memory groupMember = GroupMember(payable(msg.sender), 0, 0, 0, 0, groupMemberDonations);

        // create the group object
        Group storage group = groupDict[groupCount];
        groupMemberDict[groupCount].push(groupMember);
        
        group.id = groupCount;
        group.groupName = groupName;
        group.groupBuyInAmount = groupBuyInAmount;
        group.groupCoordinator = payable(msg.sender);
        group.groupBalance = msg.value;
        group.groupActivationTime = 0;
        group.numMembers = numGroupMembers;
        group.adminbalance = 0;

        // add to the list of groups
        groupList.push(group);

        // add the group to the user's groups
        userGroups[msg.sender].push(group);

        // add groupmember to group
        groupinfo[group.groupName].push(groupMember);
        groupinfo_i[groupCount].push(groupMember);

        // subscribe to the events
        emit createGroupEvent(group.groupCoordinator, group, address(this).balance);
        emit newGroupMemberEvent(msg.sender, group, address(this).balance);
    }




    // function to get a group by the group id
    function getGroupbyId(uint groupId)  public view returns(Group memory, GroupMember[] memory, GroupDonation[] memory) {

        require(userProfile[msg.sender].userAddress == msg.sender, "You have to be an EsusuUser to get this information");

        // returns the group info and members in the group
        Group storage group = groupDict[groupId];
        GroupMember[] storage groupMembers = groupinfo_i[groupId];
        GroupDonation[] storage groupdonations = groupDonations[groupId];
        return (group, groupMembers, groupdonations);

    }




    // function to join a group
    function joinGroup(uint groupId) payable public {

        require(userProfile[msg.sender].userAddress == msg.sender, "Create an EsusuUser account to join a group");

        // get the group 
        Group storage group = groupDict[groupId];

        // validate group buyin amount
        require(msg.value == group.groupBuyInAmount * (1 ether));

        // get the number of members in the group
        GroupMember[] storage groupMembers = groupinfo_i[groupId];
        if (groupMembers.length >= group.numMembers) {
            revert("Sorry, this group is maxed out");
        }

        for (uint i=0; i<groupMembers.length; i++) {
            if (groupMembers[i].userAddress == msg.sender) {
                revert("User already belongs to this group");
            }
        }

        // validate payment
        if(!payable(msg.sender).send(group.groupBuyInAmount)) {
            revert("Unable to transfer buyIn funds");
        }

        // create a groupMember profile
        uint[] memory groupMemberDonations;
        GroupMember memory groupMember = GroupMember(payable(msg.sender), 0, 0, 0, 0, groupMemberDonations);

        // add the group to the user's groups
        userGroups[msg.sender].push(group);

        // add groupmember to group
        groupinfo[group.groupName].push(groupMember);
        groupinfo_i[groupCount].push(groupMember);

        // increase the balance in the group
        group.groupBalance += msg.value;

        // subscribe to events
        emit newGroupMemberEvent(msg.sender, group, address(this).balance);

    }




    // function to activate group and store member payout amounts and dates
    function activateGroup(uint groupId) public {

        // get the group and groupmembers
        Group storage group = groupDict[groupId];
        GroupMember[] storage groupMembers = groupinfo_i[groupId];

        // validate
        if (msg.sender != group.groupCoordinator) {
            revert("You are not the coordinator of this group");
        }

        if (groupMembers.length != group.numMembers) {
            revert("The group is incomplete");
        }

        if (group.groupActivationTime != 0) {
            revert("This group is already active");
        }

        // set group activation time
        group.groupActivationTime = block.timestamp;
        uint lastPaymentDateCounter = group.groupActivationTime;
        emit groupActivationEvent(group, group.groupActivationTime, address(this).balance);

        // set the current donation round
        uint donationRound = 2;
        // set a pointer for donation rounds algorithm
        uint donationRoundsTimer = group.groupActivationTime;

        // set the group donation rounds
        for (uint j=1; j<groupMembers.length; j++) {
            // create GroupDonation
            uint donationRoundStartTime = donationRoundsTimer;

            // set the donation timer for 20 mins (14 days)
            uint donationRoundEndTime = donationRoundStartTime + 300;

            // set a timer for late donations (5 mins)
            uint lateDonationStartTime = donationRoundEndTime;
            uint lateDonationEndTime = lateDonationStartTime + 450;

            // save the group donation rounds
            GroupDonation memory groupdonation = GroupDonation(group, donationRound, donationRoundStartTime, donationRoundEndTime, lateDonationStartTime, lateDonationEndTime);

            // add to the mapping for groups and groupdonations
            groupDonations[groupId].push(groupdonation);

            // update the donationRoundsTimer for (30 mins) ....----....---- 27 days (1 month)
            donationRoundsTimer += 600;

            // increase the donations round
            donationRound += 1;
        }


        // set next payout and payout amounts for groupmembers
        for (uint i=0; i<groupMembers.length; i++) {
            
            GroupMember storage groupMember = groupMembers[i];

            // set the groupmember's next payout date
            groupMember.nextPaymentDate = group.groupActivationTime + 600;
        
            // TODO: ADMIN SHARE
        
            // set the payout amount (1/2 for late payment penalties and in case of missed future payments)
            groupMember.nextPaymentAmount = ((group.groupBuyInAmount * group.numMembers) - group.groupBuyInAmount) / 2;
            
            // save the amount to be paid at the end of the saving cycle
            groupMember.lastPaymentAmount = groupMember.nextPaymentAmount;
            groupMember.lastPaymentDate = lastPaymentDateCounter + (group.numMembers * 600);

            // update the group activation time (it is the counter used to calculate the payout algorithm)
            group.groupActivationTime = groupMember.nextPaymentDate;
        }

        // set admin group commision
        uint adminCommission = group.groupBuyInAmount;
        group.adminbalance += adminCommission;


    }




    // function to pay groupmember if it is the user's turn
    function payGroupMember(uint groupId) public {

        // get the group and groupmembers
        Group storage group = groupDict[groupId];
        GroupMember[] storage groupMembers = groupinfo_i[groupId];

        // validate
        if (msg.sender != group.groupCoordinator) {
            revert("You are not the coordinator of this group");
        }
        if (groupMembers.length != group.numMembers) {
            revert("The group is incomplete");
        }

        // look for the person to be paid (or track last paid)
        for (uint i=0; i<groupMembers.length; i++) {
            
            // get the groupmember and groupmember user profile
            GroupMember storage groupMember = groupMembers[i];
            EsusuUser storage userprofile = userProfile[groupMember.userAddress];
            
            // get the groupmember's next payout amount
            uint paymentAmount = groupMember.nextPaymentAmount;

            // check if his payment is valid
            if (block.timestamp >= groupMember.nextPaymentDate) {
                if (paymentAmount > 0) {

                    // payout 
                    userprofile.userBalance += paymentAmount;
                    
                    // subscribe to events
                    emit payGroupMemberEvent(group, groupMember, paymentAmount, block.timestamp, address(this).balance);
                    
                    // update the groupmember's payment amount
                    groupMember.nextPaymentAmount = 0;
                    group.groupBalance -= groupMember.nextPaymentAmount;
                }
            }
        }
    }




    // function for users to withdraw funds
    function userWithdrawal() public payable {

        require(userProfile[msg.sender].userAddress == msg.sender, "Create an EsusuUser account to access this function");

        // get the user profile
        EsusuUser storage userprofile = userProfile[msg.sender];

        // check that the user has funds 
        if (userprofile.userBalance > 0) {

            // since we deal in ether, convert the funds to be withdrawn to ether
            uint withdrawalAmount = userprofile.userBalance * (1 ether);

            // pay the user
            if (payable(msg.sender).send(withdrawalAmount)) {
                userprofile.userBalance = 0;

                // subscribe to events
                emit userWithdrawalEvent(userprofile, userprofile.userBalance, block.timestamp, address(this).balance);
            } else {
                revert("Unable to pay");
            }
        }
    }

    



    // function to collect group donations
    function userDonation(uint groupId, uint donationRound) public payable {

        // get the group and groupmembers and groupdonations
        Group storage group = groupDict[groupId];
        GroupMember[] storage groupMembers = groupinfo_i[groupId];
        GroupDonation[] storage groupdonations = groupDonations[groupId];

        // validate
        if (groupMembers.length != group.numMembers) {
            revert("The group is incomplete");
        }

        // get the amount to be paid for donation
        uint donationAmount = group.groupBuyInAmount * (1 ether);

        // validate payment amount
        if (msg.value < donationAmount) {
            revert("group payment should be group buyin amount");
        }

        // ensure the donator is a member of the group and has not paid for that round
        bool isGroupMember = false;
        for (uint i=0; i<groupMembers.length; i++) {
            if (groupMembers[i].userAddress == msg.sender) {

                // get the groupmember
                GroupMember storage groupmember = groupMembers[i];

                // check if the user has already donated for the donation round requested for
                for (uint k=0; k<groupmember.completedDonationRounds.length; k++) {
                    if (groupmember.completedDonationRounds[k] == donationRound) {
                        revert("You have already donated for this round");
                    }
                }
                isGroupMember = true;
            }
        }

        // get the donation round requested for
        GroupDonation memory selectedDonationRound;
        bool isFound_selectedDonationRound = false;
        if (isGroupMember == true) {
            // get the group donation round that was requested
            for (uint j=0; j<groupdonations.length; j++) {
                if (groupdonations[j].donationRound == donationRound) {
                    selectedDonationRound = groupdonations[j];
                    isFound_selectedDonationRound = true;
                }
            }
        } else {
            revert("You are not a member of this group");
        }

        // check that the round is still valid
        if (isFound_selectedDonationRound == true) {
            if (block.timestamp >= selectedDonationRound.donationStartTime && block.timestamp <= selectedDonationRound.donationEndTime) {

                // pay the donation
                if(!payable(msg.sender).send(group.groupBuyInAmount)) {
                    revert("Unable to add your donation funds");
                }

                // increase the group balance
                group.groupBalance += group.groupBuyInAmount;

                // add the donation round to users completed list
                for (uint m=0; m<groupMembers.length; m++) {
                    if (groupMembers[m].userAddress == msg.sender) {
                        GroupMember storage groupmember = groupMembers[m];
                        groupmember.completedDonationRounds.push(donationRound);
                    }
                }
            
            } else if (block.timestamp < selectedDonationRound.donationStartTime) {
                revert("This group round is not active yet");
            } else {
                revert("This group round is expired");
            }
        } else {
            revert("no group round of that choice");
        }
    }




    // function to accept late donations
    function lateDonation(uint groupId, uint donationRound) public payable {

        // get the group and groupmembers and groupdonations
        Group storage group = groupDict[groupId];
        GroupMember[] storage groupMembers = groupinfo_i[groupId];
        GroupDonation[] storage groupdonations = groupDonations[groupId];

        // validate
        if (groupMembers.length != group.numMembers) {
            revert("The group is incomplete");
        }

        // get the donation amount
        uint donationAmount = group.groupBuyInAmount * (1 ether);

        if (msg.value < donationAmount) {
            revert("group payment should be group buy in amount");
        }

        // ensure the donator is a member of the group and has not paid for that round
        bool isGroupMember = false;
        for (uint i=0; i<groupMembers.length; i++) {
            if (groupMembers[i].userAddress == msg.sender) {

                // get the groupmember
                GroupMember storage groupmember = groupMembers[i];

                // check if the user has already donated for the donation round requested for
                for (uint k=0; k<groupmember.completedDonationRounds.length; k++) {
                    if (groupmember.completedDonationRounds[k] == donationRound) {
                        revert("You have already donated for this round");
                    }
                }
                isGroupMember = true;
            }
        }

        // get the donation round requested for
        GroupDonation memory selectedDonationRound;
        bool isFound_selectedDonationRound = false;
        if (isGroupMember == true) {
            // get the group donation round that was requested
            for (uint j=0; j<groupdonations.length; j++) {
                if (groupdonations[j].donationRound == donationRound) {
                    selectedDonationRound = groupdonations[j];
                    isFound_selectedDonationRound = true;
                }
            }
        } else {
            revert("You are not a member of this group");
        }

        // check that the round is still valid for late payment
        if (isFound_selectedDonationRound == true) {
            if (block.timestamp >= selectedDonationRound.latePaymentStartTime && block.timestamp <= selectedDonationRound.latePaymentEndTime) {

                // pay the donation
                if(!payable(msg.sender).send(group.groupBuyInAmount)) {
                    revert("Unable to transfer donation funds");
                }

                // increase the group balance
                group.groupBalance += group.groupBuyInAmount;

                // add the donation round to users completed list
                for (uint m=0; m<groupMembers.length; m++) {
                    if (groupMembers[m].userAddress == msg.sender) {
                        GroupMember storage groupmember = groupMembers[m];
                        groupmember.completedDonationRounds.push(donationRound);

                        // add the penalty for late payment
                        groupmember.lastPaymentAmount -= group.groupBuyInAmount / 2;
                    }
                }
            
            } else if (block.timestamp < selectedDonationRound.donationStartTime) {
                revert("The late payment for this group round is not active yet");
            } else {
                revert("The late payment for thsi group round is expired");
            }
        } else {
            revert("no group round of this choice");
        }

    }

    // function for last payment
    function groupMembersLastPayout(uint groupId) public payable  {

        // get the group and group members
        Group storage group = groupDict[groupId];
        GroupMember[] storage groupMembers = groupinfo_i[groupId];

        // validate
        if (msg.sender != group.groupCoordinator) {
            revert("You are not the coordinator of this group");
        }
        if (groupMembers.length != group.numMembers) {
            revert("The group is incomplete");
        }

        // get the last groupmember last payout time
        GroupMember storage lastGroupMember = groupMembers[groupMembers.length-1];

        // check if last payment is due
        if (block.timestamp >= lastGroupMember.lastPaymentDate) {
            
            // pay everybody
            for (uint i=0; i<groupMembers.length; i++) {
                
                // get the groupmember and groupmember user profile
                GroupMember storage groupMember = groupMembers[i];
                EsusuUser storage userprofile = userProfile[groupMember.userAddress];

                userprofile.userBalance += groupMember.lastPaymentAmount;

                // subscribe to events
                emit lastGroupPaymentEvent(group, groupMember, groupMember.lastPaymentAmount, block.timestamp, address(this).balance);

                // update the groupmember's payment amount
                groupMember.lastPaymentAmount = 0;
                group.groupBalance -= groupMember.lastPaymentAmount;

            }

            // pay the admin
            // since we deal in ether, convert the funds to be withdrawn to ether
            uint withdrawalAmount = group.adminbalance * (1 ether);

            // pay the admin
            if (payable(esusuAdmin).send(withdrawalAmount)) {
                group.adminbalance = 0;

                // subscribe to events
                // emit userWithdrawalEvent(userprofile, userprofile.userBalance, block.timestamp, address(this).balance);
            } else {
                revert("Unable to pay admin");
            }


        } else {
                revert("Sorry, Last payment is not active yet");
            }


    }
}