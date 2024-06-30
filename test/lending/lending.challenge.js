const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Lending Contract', function () {
    let deployer, player1, player2, player3, player4;
    let lendingContract, mockToken;

    beforeEach(async function () {
        [deployer, player1, player2, player3, player4] = await ethers.getSigners();

        const MockToken = await ethers.getContractFactory('MockToken', deployer);
        mockToken = await MockToken.deploy();
        await mockToken.deployed();

        const Lending = await ethers.getContractFactory('LendingPool', deployer);
        lendingContract = await Lending.deploy();
        await lendingContract.deployed();

        // Mint some tokens for the players
        await mockToken.mint(player1.address, ethers.utils.parseEther('1000'));
        await mockToken.mint(player2.address, ethers.utils.parseEther('1000'));
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


});
