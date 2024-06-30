const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Lending Contract', function () {
    let deployer, player1, player2, player3, player4;
    let lendingContract, mockToken;

    beforeEach(async function () {
        [deployer, player1, player2, player3, player4] = await ethers.getSigners();


        // Deploy TimelockController
        const timelock = await ethers.getContractFactory("TimeLock");
        const timelockInstance = await timelock.deploy(86400,[],[],deployer.address); // 1 day timelock
        await timelockInstance.deployed();

        const MockToken = await ethers.getContractFactory('MockToken', deployer);
        mockToken = await MockToken.deploy();
        await mockToken.deployed();

        

        // Deploy GovernorContract
        const governorContractFactory = await ethers.getContractFactory("GovernorContract");
        governorContract = await governorContractFactory.deploy(
            mockToken.address,
            timelockInstance.address,
            50,    // Quorum percentage (50%)
            120,  // Voting period (2 hours)
            1     // Voting delay (1 block)
        );
        await governorContract.deployed();


        

        const Lending = await ethers.getContractFactory('LendingPool', deployer);
        lendingContract = await Lending.deploy(governorContract.address);
        await lendingContract.deployed();

        await mockToken.mint(player1.address, ethers.utils.parseEther('1000'));
        await mockToken.mint(player2.address, ethers.utils.parseEther('1000'));
        // await mockToken.connect(player1).delegate(player1.address);
        // await mockToken.connect(player2).delegate(player2.address);
    });

    it('Should deposit correctly', async function () {
        const amount = ethers.utils.parseEther('100'); 
        await mockToken.connect(player1).approve(lendingContract.address, amount);
        await lendingContract.connect(player1).deposit(mockToken.address, amount);

        const collateral = await lendingContract.userCollateral(player1.address, mockToken.address);
        expect(collateral).to.equal(amount, 'Player should have deposited the correct amount');
    });


    it('Should withdraw correctly', async function () {
        const depositAmount = ethers.utils.parseEther('100');
        const withdrawAmount = ethers.utils.parseEther('50'); 

        await mockToken.connect(player1).approve(lendingContract.address, depositAmount);
        await lendingContract.connect(player1).deposit(mockToken.address, depositAmount);

        await lendingContract.connect(player1).withdraw(mockToken.address, withdrawAmount);

        const collateral = await lendingContract.userCollateral(player1.address, mockToken.address);
        expect(collateral).to.equal(depositAmount.sub(withdrawAmount), 'Player should have withdrawn the correct amount');
    });

    it('Should fail to withdraw more than deposited', async function () {
        const depositAmount = ethers.utils.parseEther('100');
        const withdrawAmount = ethers.utils.parseEther('150'); 

        await mockToken.connect(player1).approve(lendingContract.address, depositAmount);
        await lendingContract.connect(player1).deposit(mockToken.address, depositAmount);

        await expect(
            lendingContract.connect(player1).withdraw(mockToken.address, withdrawAmount)
        ).to.be.revertedWith('Not enough liquidity');
    });

    it('Should borrow correctly', async function () {
        const depositAmount = ethers.utils.parseEther('100'); // 100 tokens
        const borrowAmount = ethers.utils.parseEther('25'); // 25 tokens

        await mockToken.connect(player1).approve(lendingContract.address, depositAmount);
        await lendingContract.connect(player1).deposit(mockToken.address, depositAmount);

        await lendingContract.connect(player1).borrow(mockToken.address, borrowAmount);

        const loan = await lendingContract.loans(player1.address, mockToken.address);
        expect(loan.principal).to.equal(borrowAmount, 'Player should have borrowed the correct amount');
    });


    it('Should fail to borrow without enough collateral', async function () {
        const depositAmount = ethers.utils.parseEther('50'); // 50 tokens
        const borrowAmount = ethers.utils.parseEther('50'); // 50 tokens

        await mockToken.connect(player1).approve(lendingContract.address, depositAmount);
        await lendingContract.connect(player1).deposit(mockToken.address, depositAmount)

        await expect(
            lendingContract.connect(player1).borrow(mockToken.address, borrowAmount)
        ).to.be.revertedWith('Insufficient collateral');
    });


    it('Should fail to borrow more than liquidity', async function () {
        const depositAmount = ethers.utils.parseEther('1000'); // 500 tokens
        const borrowAmount = ethers.utils.parseEther('500'); // 1000 tokens
    
        await mockToken.connect(player1).approve(lendingContract.address, depositAmount);
        await lendingContract.connect(player1).deposit(mockToken.address, depositAmount);

        await lendingContract.connect(player1).withdraw(mockToken.address, depositAmount)


        await expect(
            lendingContract.connect(player1).borrow(mockToken.address, borrowAmount)
        ).to.be.revertedWith('Insufficient collateral');
    });



    it('Should fail to borrow more than collateral', async function () {
        const depositAmount = ethers.utils.parseEther('1000'); // 500 tokens
        const borrowAmount = ethers.utils.parseEther('500'); // 1000 tokens
    
        await mockToken.connect(player1).approve(lendingContract.address, depositAmount);
        await lendingContract.connect(player1).deposit(mockToken.address, depositAmount);

        await lendingContract.connect(player1).withdraw(mockToken.address, depositAmount)


        await expect(
            lendingContract.connect(player1).borrow(mockToken.address, borrowAmount)
        ).to.be.revertedWith('Insufficient collateral');
    });
    

    it('Should create a Governor proposal correctly', async function () {
        const proposalDescription = "Proposal to test";
    
        // Delegate tokens to self to enable voting
        const delegateTx = await mockToken.connect(player1).delegate(player1.address);
        await delegateTx.wait();
    
        // Get current block number before mining
        const currentBlockBefore = await ethers.provider.getBlockNumber();
        console.log("Current Block Number Before Mining:", currentBlockBefore);
    
        // Mine a block after delegation
        await ethers.provider.send("evm_mine", []);
    
        // Get current block number after mining
        const currentBlockAfter = await ethers.provider.getBlockNumber();
        console.log("Current Block Number After Mining:", currentBlockAfter);
    
        // Check voting power after delegation
        const player1Votes = await governorContract.getVotes(player1.address, currentBlockAfter);
    
        // Define proposal details
        const targets = [];
        const values = [];
        const calldatas = [];
    
        // Create a proposal
        const proposeTx = await governorContract.connect(player1).propose(targets, values, calldatas, proposalDescription);
        const proposeReceipt = await proposeTx.wait();
    
        // Retrieve proposal ID from emitted event
        const proposalId = proposeReceipt.events.find(event => event.event === 'ProposalCreated').args.proposalId;
    
        // Retrieve proposal details
        const proposal = await governorContract.proposals(proposalId);
    
        // Assert that the proposal was created successfully
        expect(proposal.proposalId).to.equal(proposalId, "Proposal ID should match");
    });
    
});
