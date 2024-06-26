// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "hardhat/console.sol";

contract GovernorContract is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    struct Proposal {
        uint256 proposalId;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }


    mapping(address => mapping(uint256 => bool)) public hasVoted;

    mapping(uint256 => uint256) public totalVotesForProposal;
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // Function to get the total vote count for a proposal
    function getTotalVotesForProposal(
        uint256 proposalId
    ) public view returns (uint256) {
        return totalVotesForProposal[proposalId];
    }

    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint256 _quorumPercentage,
        uint256 _votingPeriod,
        uint256 _votingDelay
    )
        Governor("GovernorContract")
        GovernorSettings(_votingDelay, _votingPeriod, 1)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {}

    function getProposal(
        uint256 proposalId
    ) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function createProposal(
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external {


        proposalCount++;
        uint256 proposalId = proposalCount;
   
        uint256 proposalUId = propose(targets, values, calldatas, description);


        proposals[proposalId] = Proposal({
            proposalId: proposalUId,
            description: description,
            proposer: msg.sender,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });
    
    }

    function vote(uint256 proposalId, bool support) external {

         address voter = msg.sender;
        require(!hasVoted[voter][proposalId], "Already voted on this proposal");

        require(
            state(proposalId) == ProposalState.Active,
            "Governor: voting is closed"
        );

        hasVoted[voter][proposalId] = true;


        Proposal storage proposal = proposals[proposalId];

        uint256 weight = getVotes(msg.sender, block.number - 1);
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support ? 1 : 0, weight, "");
    }

    function executeProposal(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor: proposal not succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);

        _execute(
            proposalId,
            targets,
            values,
            calldatas,
            keccak256(bytes(proposal.description))
        );
    }

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function getVotes(
        address account,
        uint256 blockNumber
    ) public view override(IGovernor, Governor) returns (uint256) {
        return super.getVotes(account, blockNumber);
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function getProposalVotes(
        uint256 proposalId
    ) external view returns (uint256 forVotes, uint256 againstVotes) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes);
    }


    function proposalExists(uint256 proposalId) public view returns (bool) {
        return proposals[proposalId].proposalId == proposalId;
    }

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public override(Governor,IGovernor) returns (uint256) {
        require(support <= 2, "Governor: invalid vote type");
        address voter = _msgSender();

        // Check that the proposal exists
        require(
            proposalExists(proposalId),
            "Governor: proposal does not exist"
        );

        // Update the total votes for the proposal
        totalVotesForProposal[proposalId]++;

        // Call the inherited implementation to cast the vote
        super.castVoteWithReason(proposalId, support, reason);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
