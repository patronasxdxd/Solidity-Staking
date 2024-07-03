import { ethers } from 'hardhat';
import { LendingPool } from '../contracts/lending/LendingPool.sol'
import { network } from "hardhat"


async function main() {
  const [deployer, player1, player2, player3] = await ethers.getSigners();

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



  console.log('Voting power delegated.');

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



  const proposerRole = await timelockInstance.PROPOSER_ROLE()
  const executorRole = await timelockInstance.EXECUTOR_ROLE()

  const proposerTx = await timelockInstance.grantRole(proposerRole, governorContract.address)
  await proposerTx.wait(1)
  const executorTx = await timelockInstance.grantRole(executorRole, governorContract.address)
  await executorTx.wait(1)

  const proposerTx2 = await timelockInstance.grantRole(proposerRole, player1.address)
  await proposerTx2.wait(1)
  const executorTx2 = await timelockInstance.grantRole(executorRole, player1.address)
  await executorTx2.wait(1)



  // Deploy lendingContract
  const Lending = await ethers.getContractFactory('LendingPool');
  const lendingContract = await Lending.deploy(governorContract.address);
  await lendingContract.deployed();
  console.log('MockToken deployed to:', lendingContract.address);


  const lendingContracting = (await ethers.getContractAt(
    "LendingPool",
    lendingContract.address
  )) as LendingPool;






  // Delegate voting power to the deployer (optional step if your contract supports delegation)
  // Example: delegate voting power from player1 to deployer
  await mockToken.connect(player1).delegate(player1.address);


  const description = "Mint Tokens Proposal";

  // Example: minting tokens as an action
  const mintAction = {
    target: mockToken.address,
    callData: mockToken.interface.encodeFunctionData('mint', [player1.address, ethers.utils.parseEther('123')])
  };

  // Ensure targets, values, and calldatas are correctly populated
  const targets = [mintAction.target];
  const values = [0]; // Example value, adjust as needed
  const calldatas = [mintAction.callData];

  // Create the proposal
  await governorContract.connect(player1).createProposal(description, targets, values, calldatas);
  // console.log(`Proposal created with ID: ${proposalId}`);

  // const proposalId = await lendingContracting.connect(player1).createGovernorProposal(description);



  // console.log(`Proposal created with ID: ${proposalId}`);


  let proposal = await governorContract.getProposal(1);
  let proposalIdx = proposal.proposalId.toString();

  console.log(`Proposal ID: ${proposal.proposalId}`);
  console.log(`Description: ${proposal.description}`);
  console.log(`Proposer: ${proposal.proposer}`);
  console.log(`For Votes: ${proposal.forVotes.toString()}`);
  console.log(`Against Votes: ${proposal.againstVotes.toString()}`);
  console.log(`Executed: ${proposal.executed}`);




  // // to go forward 1 block
  await mockToken.mockMineBlock()


  // state 0 means pending
  // state 1 means active
  await governorContract.connect(player1).vote(proposal.proposalId, true);
  // await governorContract.connect(player1).vote(proposal.proposalId, true);


  


  await mockToken.mockMineBlock()

  // await mockToken.connect(player1).transfer(player3.address, ethers.utils.parseEther('100'));

  // await mockToken.connect(player3).delegate(player3.address);

  proposal = await governorContract.getProposal(1);
  proposalIdx = proposal.proposalId.toString();

  console.log(`Proposal ID: ${proposal.proposalId}`);
  console.log(`Description: ${proposal.description}`);
  console.log(`Proposer: ${proposal.proposer}`);
  console.log(`For Votes: ${proposal.forVotes.toString()}`);
  console.log(`Against Votes: ${proposal.againstVotes.toString()}`);
  console.log(`Executed: ${proposal.executed}`);

  await mockToken.mockMineBlock()

  const currentBlock = await ethers.provider.getBlockNumber();
  console.log(`Current block number: ${currentBlock}`);

  // await governorContract.connect(player3).vote(proposal.proposalId, false);


  //cant vote twice now
  // await lendingContract.connect(player1).voteGovernorProposal(proposal.proposalId, true);



  console.log("saw");

  console.log(await governorContract.connect(player1).proposalSnapshot(proposal.proposalId))
  console.log(await governorContract.connect(player1).proposalDeadline(proposal.proposalId))


  const [forVotes, againstVotes] = await governorContract.connect(player1).getProposalVotes(proposal.proposalId);

  await mockToken.mockMineBlock()
  console.log(await governorContract.state(proposal.proposalId))
  await mockToken.mockMineBlock()
  await mockToken.mockMineBlock()
  await mockToken.mockMineBlock()
  await mockToken.mockMineBlock()

  await mockToken.mockMineBlock()
  console.log(await governorContract.state(proposal.proposalId))





  //QUE OPERATION
  const descriptionHash = ethers.utils.id(description);
  await governorContract.queue(targets, values, calldatas, descriptionHash);



  // await ethers.provider.send("evm_increaseTime", [300]);
  // await ethers.provider.send("evm_mine", []);
// Check balance of player1
let balancePlayer1 = await mockToken.balanceOf(player1.address);
console.log(`Balance of player1: ${ethers.utils.formatEther(balancePlayer1)} tokens`);


console.log(await governorContract.state(proposal.proposalId))

await governorContract.executeProposal(1);

console.log(await governorContract.state(proposal.proposalId))




  console.log('voting count for votes now?', forVotes)
  console.log('voting count against votes now?', againstVotes)
  console.log('Deployment and proposal creation completed successfully.');



  console.log( await timelockInstance.getCurrentBlockTimestamp())
  console.log( await timelockInstance.getOperationTimestamp())
  console.log( await timelockInstance.getID())

  console.log( await timelockInstance.getDoneTimestamp())


  // Check balance of player1
balancePlayer1 = await mockToken.balanceOf(player1.address);
console.log(`Balance of player1: ${ethers.utils.formatEther(balancePlayer1)} tokens`);

await mockToken.mockMineBlock()
console.log(await governorContract.state(proposal.proposalId))



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
