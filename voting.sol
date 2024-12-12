// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract Voting {
    address public admin; // Address of the contract admin

    bool public isVoting;
    uint public totalVotes;
    uint public remainingVotes;
    address public winner;

    struct Vote {
        address[] preferences; // Voter's ranked preferences (by address)
    }

    mapping(address => Vote) private votes;
    mapping(address => uint256) public voteCounts; // Total votes for each candidate
    mapping(address => bool) public eliminated; // Track eliminated candidates
    mapping(string => address) public nameToAddress; // Map candidate names to addresses
    address[] public voters;
    address[] public candidates;
    mapping(address => string) public candidateNames;
    mapping(address => bool) public hasVoted; // Track if a voter has already voted

    event AddVote(address indexed voter, address[] preferences, uint256 timestamp);
    event RemoveVote(address voter);
    event StartVoting(address startedBy);
    event StopVoting(address stoppedBy);
    event AnnounceWinner(address winner);

    constructor() public {
        admin = msg.sender; // Set the deployer as the initial admin
    }

    function startVoting() external onlyAdmin returns (bool) {
        isVoting = true;
        totalVotes = 0;
        remainingVotes = 0;
        winner = address(0);
        emit StartVoting(msg.sender);
        return true;
    }

    function stopVoting() external onlyAdmin returns (bool) {
        isVoting = false;
        emit StopVoting(msg.sender);
        announceWinner();
        return true;
    }

    function addCandidate(address candidate, string memory name) external onlyAdmin returns (bool) {
        require(isVoting, "Voting is not active");
        candidates.push(candidate);
        candidateNames[candidate] = name;
        nameToAddress[name] = candidate; // Map the name to the candidate's address
        voteCounts[candidate] = 0;
        return true;
    }

    function addVote(string[] memory preferences) external returns (bool) {
        require(isVoting, "Voting is not active");
        require(preferences.length == candidates.length, "Preferences should cover all candidates");
        require(votes[msg.sender].preferences.length == 0, "You have already voted"); // Check if voter has any existing vote

        address[] memory preferenceAddresses = new address[](preferences.length);

        // Convert candidate names to addresses
        for (uint i = 0; i < preferences.length; i++) {
            address candidateAddress = nameToAddress[preferences[i]];
            require(candidateAddress != address(0), "Invalid candidate name");
            preferenceAddresses[i] = candidateAddress;
        }

        // Store the vote preferences of the voter
        votes[msg.sender] = Vote(preferenceAddresses);
        voters.push(msg.sender);
        totalVotes += 1;
        remainingVotes += 1;

        // Count the vote for the first preference
        address firstChoice = preferenceAddresses[0];
        voteCounts[firstChoice] += 1;

        hasVoted[msg.sender] = true; // Mark the voter as having voted

        emit AddVote(msg.sender, preferenceAddresses, block.timestamp);
        return true;
    }

    function removeVote() external returns (bool) {
        Vote memory voterVote = votes[msg.sender];
        if (voterVote.preferences.length > 0) {
            address firstChoice = voterVote.preferences[0];
            voteCounts[firstChoice] -= 1;
            remainingVotes -= 1;

            // Clear the voter's preferences
            delete votes[msg.sender];
    }

    emit RemoveVote(msg.sender);
    return true;
    }

    function getVote(address voterAddress) external view returns (address[] memory preferences) {
        return votes[voterAddress].preferences;
    }

    function announceWinner() internal {
        while (remainingVotes > 0) {
            // Find the candidate with the fewest votes
            address loser = findLoser();
            eliminated[loser] = true;
            remainingVotes -= voteCounts[loser];

            // Recalculate vote counts, eliminate the lowest candidate, and redistribute votes
            redistributeVotes();

            // Check if any candidate has more than 50% of the remaining votes
            for (uint i = 0; i < candidates.length; i++) {
                address candidate = candidates[i];
                if (!eliminated[candidate] && voteCounts[candidate] > remainingVotes / 2) {
                    winner = candidate;
                    emit AnnounceWinner(winner);
                    return;
                }
            }
        }
    }

    function redistributeVotes() internal {
        // Go through all voters and update their votes if their preferred candidate is eliminated
        for (uint i = 0; i < voters.length; i++) {
            address voter = voters[i];
            Vote storage voterVote = votes[voter];

            // Try to find the next preference that is still not eliminated
            for (uint j = 0; j < voterVote.preferences.length; j++) {
                address candidate = voterVote.preferences[j];
                if (!eliminated[candidate]) {
                    voteCounts[candidate] += 1;
                    break;
                }
            }
        }
    }

    function findLoser() internal view returns (address) {
        address loser;
        uint256 minVotes = totalVotes + 1;

        // Find the candidate with the least votes
        for (uint i = 0; i < candidates.length; i++) {
            address candidate = candidates[i];
            if (!eliminated[candidate] && voteCounts[candidate] < minVotes) {
                minVotes = voteCounts[candidate];
                loser = candidate;
            }
        }

        return loser;
    }

    function getWinner() external view returns (string memory) {
        return candidateNames[winner];
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;}
}