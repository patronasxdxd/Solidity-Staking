import { ethers } from 'hardhat';
import {LendingPool} from '../contracts/lending/LendingPool.sol'


async function main() {
    const [deployer, player1, player2] = await ethers.getSigners();

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
    await mockToken.connect(player1).mint(player1.address, ethers.utils.parseEther('1000'));
    await mockToken.connect(player2).mint(player2.address, ethers.utils.parseEther('1000'));

    // Delegate voting power to the deployer (optional step if your contract supports delegation)
    // Example: delegate voting power from player1 to deployer
    await mockToken.connect(player1).delegate(deployer.address);

    console.log('Voting power delegated.');

    // Deploy GovernorContract
    const governorContractFactory = await ethers.getContractFactory("GovernorContract");
    const governorContract = await governorContractFactory.deploy(
        mockToken.address,
        timelockInstance.address,
        50,    // Quorum percentage (50%)
        120,   // Voting period (2 hours)
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
    


       


    // Create a proposal with minting tokens as an action
    const description = "Mint Tokens Proposal";
    const mintAction = {
        target: mockToken.address,
        callData: mockToken.interface.encodeFunctionData('mint', [player1.address, ethers.utils.parseEther('1')])
    };


    const proposalId = await lendingContracting.createGovernorProposal(description);

    console.log(`Proposal created with ID: ${proposalId}`);

    await lendingContract.connect(player1).voteGovernorProposal(1, true, {
        gasLimit: 5000000  // Example gas limit, adjust as needed
    });

    console.log('Proposal voted on by Player1.');


    console.log(await governorContract.getProposal(0))

    console.log(await governorContract.getProposal(1))
    

    const [forVotes, againstVotes] = await lendingContracting.connect(player1).getGovernorProposalVotes(1);

    console.log('voting count for votes now?',forVotes)
    console.log('voting count against votes now?',againstVotes)
    console.log('Deployment and proposal creation completed successfully.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
