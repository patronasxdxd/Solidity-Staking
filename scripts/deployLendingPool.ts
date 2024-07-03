import { ethers } from 'hardhat';
import { LendingPool } from '../contracts/lending/LendingPool.sol'
import { network } from "hardhat"

async function main() {
  const [deployer, player1, player2, player3] = await ethers.getSigners();

  console.log('');
  console.log('--------------- Stage 1: Deploying Contracts ---------------');
  console.log('Deploying contracts with the following addresses:');
  console.log('Deployer:', deployer.address);
  console.log('Player1:', player1.address);
  console.log('Player2:', player2.address);

  // Deploy TimelockController
  const timelock = await ethers.getContractFactory("TimeLock");
  const timelockInstance = await timelock.deploy(0, [], [], deployer.address); // 1 day timelock
  await timelockInstance.deployed();
  console.log('Timelock deployed to:', timelockInstance.address);

  // Deploy MockToken
  const MockToken = await ethers.getContractFactory('MockToken');
  const mockToken = await MockToken.deploy();
  await mockToken.deployed();
  console.log('MockToken deployed to:', mockToken.address);

  // Mint tokens for players
  await mockToken.connect(player1).mint(player1.address, ethers.utils.parseEther('1100'));
  await mockToken.connect(player2).mint(player2.address, ethers.utils.parseEther('1000'));
  console.log('Tokens minted for Player1 and Player2.');

  console.log('');
  console.log('--------------- Stage 2: Deploying GovernorContract ---------------');
  // Deploy GovernorContract
  const governorContractFactory = await ethers.getContractFactory("GovernorContract");
  const governorContract = await governorContractFactory.deploy(
    mockToken.address,
    timelockInstance.address,
    4,    // Quorum percentage (50%)
    6,   // Voting period (6 seconds/blocks)
    1      // Voting delay (1 block)
  );
  await governorContract.deployed();
  console.log('GovernorContract deployed to:', governorContract.address);

  const proposerRole = await timelockInstance.PROPOSER_ROLE();
  const executorRole = await timelockInstance.EXECUTOR_ROLE();
  const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

  const proposerTx = await timelockInstance.grantRole(proposerRole, governorContract.address);
  await proposerTx.wait(1);
  const executorTx = await timelockInstance.grantRole(executorRole, ADDRESS_ZERO);
  await executorTx.wait(1);
  console.log('Roles assigned to GovernorContract.');

  console.log('');
  console.log('--------------- Stage 3: Deploying LendingPool ---------------');
  // Deploy lendingContract
  const Lending = await ethers.getContractFactory('LendingPool');
  const lendingContract = await Lending.deploy(governorContract.address);
  await lendingContract.deployed();
  console.log('LendingPool deployed to:', lendingContract.address);

  const lendingContracting = (await ethers.getContractAt(
    "LendingPool",
    lendingContract.address
  )) as LendingPool;

  console.log('');
  console.log('--------------- Stage 4: Creating Proposal ---------------');
  // Delegate voting power to the deployer (optional step if your contract supports delegation)
  await mockToken.connect(player1).delegate(player1.address);

  const description = "Mint Tokens Proposal";
  const mintAction = {
    target: mockToken.address,
    callData: mockToken.interface.encodeFunctionData('mint', [player1.address, ethers.utils.parseEther('123')])
  };
  const targets = [mintAction.target];
  const values = [0]; // Example value, adjust as needed
  const calldatas = [mintAction.callData];

  // Create the proposal
  await governorContract.connect(player1).createProposal(description, targets, values, calldatas);

  let proposal = await governorContract.getProposal(1);
  let proposalIdx = proposal.proposalId.toString();

  console.log(`Proposal ID: ${proposal.proposalId}`);
  console.log(`Description: ${proposal.description}`);
  console.log(`Proposer: ${proposal.proposer}`);
  console.log(`For Votes: ${proposal.forVotes.toString()}`);
  console.log(`Against Votes: ${proposal.againstVotes.toString()}`);
  console.log(`Executed: ${proposal.executed}`);

  console.log('');
  console.log('--------------- Stage 5: Voting on Proposal ---------------');
  await mockToken.mockMineBlock();
  await governorContract.connect(player1).vote(1, true);

  await mockToken.mockMineBlock();

  proposal = await governorContract.getProposal(1);
  proposalIdx = proposal.proposalId.toString();

  console.log(`Proposal ID: ${proposal.proposalId}`);
  console.log(`Description: ${proposal.description}`);
  console.log(`Proposer: ${proposal.proposer}`);
  console.log(`For Votes: ${proposal.forVotes.toString()}`);
  console.log(`Against Votes: ${proposal.againstVotes.toString()}`);
  console.log(`Executed: ${proposal.executed}`);

  await mockToken.mockMineBlock();
  const currentBlock = await ethers.provider.getBlockNumber();
  console.log(`Current block number: ${currentBlock}`);

  console.log('');
  console.log('--------------- Stage 6: Executing Proposal ---------------');

  const [forVotes, againstVotes] = await governorContract.connect(player1).getProposalVotes(proposal.proposalId);
  await mockToken.mockMineBlock();
  console.log("current state:", await governorContract.state(proposal.proposalId));
  await mockToken.mockMineBlock();
  await mockToken.mockMineBlock();
  await mockToken.mockMineBlock();
  await mockToken.mockMineBlock();

  console.log('Queuing operation...');
  const descriptionHash = ethers.utils.id(description);
  await governorContract.queue(targets, values, calldatas, descriptionHash);

  let balancePlayer1 = await mockToken.balanceOf(player1.address);
  console.log(`Balance of player1: ${ethers.utils.formatEther(balancePlayer1)} tokens`);

  await governorContract.executeProposal(1);

  console.log("current state:", await governorContract.state(proposal.proposalId));
  console.log('Execution of proposal completed.');

  console.log('');
  console.log('--------------- Stage 7: Finalizing ---------------');
  console.log('Voting count for votes now:', forVotes);
  console.log('Voting count against votes now:', againstVotes);
  console.log('Deployment and proposal creation completed successfully.');

  console.log(await timelockInstance.getCurrentBlockTimestamp());
  console.log(await timelockInstance.getOperationTimestamp());
  console.log(await timelockInstance.getID());
  console.log(await timelockInstance.getDoneTimestamp());

  balancePlayer1 = await mockToken.balanceOf(player1.address);
  console.log(`Balance of player1: ${ethers.utils.formatEther(balancePlayer1)} tokens`);

  await mockToken.mockMineBlock();
  console.log("current state:", await governorContract.state(proposal.proposalId));

  let proposal2 = await governorContract.getProposal(1);
  let proposalIdx2 = proposal2.proposalId.toString();

  console.log(`Proposal ID: ${proposal2.proposalId}`);
  console.log(`Description: ${proposal2.description}`);
  console.log(`Proposer: ${proposal2.proposer}`);
  console.log(`For Votes: ${proposal2.forVotes.toString()}`);
  console.log(`Against Votes: ${proposal2.againstVotes.toString()}`);
  console.log(`Executed: ${proposal2.executed}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
