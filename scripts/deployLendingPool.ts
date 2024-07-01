import { ethers } from 'hardhat';
import {LendingPool} from '../contracts/lending/LendingPool.sol'


async function main() {
  const [deployer, player1, player2, player3] = await ethers.getSigners();

    console.log('Deploying contracts with the following addresses:');
    console.log('Deployer:', deployer.address);
    console.log('Player1:', player1.address);
    console.log('Player2:', player2.address);


    // Deploy TimelockController
    const timelock = await ethers.getContractFactory("TimeLock");
    const timelockInstance = await timelock.deploy(86400, [], [], deployer.address); // 1 day timelock
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
        2000,   // Voting period (2 hours)
        1      // Voting delay (1 block)
    );
    await governorContract.deployed();
    console.log('GovernorContract deployed to:', governorContract.address);



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
      callData: mockToken.interface.encodeFunctionData('mint', [player1.address, ethers.utils.parseEther('1')])
  };
  
  // Ensure targets, values, and calldatas are correctly populated
  const targets = [mintAction.target];
  const values = [0]; // Example value, adjust as needed
  const calldatas = [mintAction.callData];
  
  // Create the proposal
  await governorContract.connect(player1).createProposal(description,targets, values, calldatas);
  // console.log(`Proposal created with ID: ${proposalId}`);

    // const proposalId = await lendingContracting.connect(player1).createGovernorProposal(description);

  

    // console.log(`Proposal created with ID: ${proposalId}`);


    const proposal = await governorContract.getProposal(1);
    const proposalIdx = proposal.proposalId.toString();
    
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


      await mockToken.connect(player1).transfer(player3.address, ethers.utils.parseEther('100'));

      await mockToken.connect(player3).delegate(player3.address);

      await governorContract.connect(player3).vote(proposal.proposalId, false);


      //cant vote twice now
      // await lendingContract.connect(player1).voteGovernorProposal(proposal.proposalId, true);



      const [forVotes, againstVotes] = await governorContract.connect(player1).getProposalVotes(proposal.proposalId);

        console.log('voting count for votes now?',forVotes)
    console.log('voting count against votes now?',againstVotes)
    console.log('Deployment and proposal creation completed successfully.');
    // console.log('Deployment and proposal creation completed successfully.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
