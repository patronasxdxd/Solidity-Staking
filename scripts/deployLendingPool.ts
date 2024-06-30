import { ethers } from 'hardhat';

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

    // Deploy LendingPool
    const Lending = await ethers.getContractFactory('LendingPool');
    const lendingContract = await Lending.deploy(governorContract.address);
    await lendingContract.deployed();
    console.log('LendingPool deployed to:', lendingContract.address);

    // Mint tokens for players
    await mockToken.connect(player1).mint(player1.address, ethers.utils.parseEther('1000'));
    await mockToken.connect(player2).mint(player2.address, ethers.utils.parseEther('1000'));

    // Create a proposal
    const description = "Sample Proposal"; // Replace with actual description
    const proposalId = await governorContract.createProposal(description);

    console.log(`Proposal created with ID: ${proposalId}`);

    // Optionally vote on the proposal
    // Example: voting in favor of the proposal
    await governorContract.connect(player1).vote(proposalId, true);

    console.log('Proposal voted on by Player1.');

    // Example: execute the proposal (after voting period and if quorum is met)
    // await governorContract.executeProposal(proposalId);

    console.log('Deployment and proposal creation completed successfully.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
