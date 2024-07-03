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
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
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
            executed: false,
            targets: targets,
            values: values,
            calldatas: calldatas
        });
    }

    function vote(uint256 proposalId, bool support) external {
        address voter = msg.sender;
    
        Proposal storage proposal = proposals[proposalId];


        require(!hasVoted[voter][proposal.proposalId], "Already voted on this proposal");


        require(
            state(proposal.proposalId) == ProposalState.Active,
            "Governor: voting is closed"
        );


        hasVoted[voter][proposal.proposalId] = true;

        // only get the voting power at the time the proposal started.
        uint256 weight = getVotes(voter, proposalSnapshot(proposal.proposalId)); 
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        super.castVote(proposal.proposalId, support ? 1 : 0);
        emit VoteCast(msg.sender, proposalId, support ? 1 : 0, weight, "");
    }

    function executeProposal(uint256 proposalId) external {
       
        Proposal storage proposal = proposals[proposalId];
        


        require(
            state(proposal.proposalId) == ProposalState.Queued,
            "Governor: proposal not succeeded"
        );

        proposal.executed = true;

        _execute(
            proposal.proposalId,
            proposal.targets,
            proposal.values,
            proposal.calldatas,
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IGovernor-proposalSnapshot}.
     */
    function proposalSnapshot(
        uint256 proposalId
    ) public view virtual override(Governor, IGovernor) returns (uint256) {
        return super.proposalSnapshot(proposalId);
    }

    /**
     * @dev See {IGovernor-proposalDeadline}.
     */
    function proposalDeadline(
        uint256 proposalId
    ) public view virtual override(Governor, IGovernor) returns (uint256) {
        return super.proposalDeadline(proposalId);
    }
}
