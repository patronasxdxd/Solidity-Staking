const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Staking Contract', function () {
    let deployer, player1, player2, player3, player4;
    let stakingContract;

    before(async function () {
        [deployer, player1, player2, player3, player4] = await ethers.getSigners();
        const Staking = await ethers.getContractFactory('Staking', deployer);
        stakingContract = await Staking.deploy();
        await stakingContract.deployed();
    });

    it("Should have deposited correctly", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", amount, {
            value: amount
        });

        const balance = await stakingContract.getBalancePlayer(player1.address);
        expect(balance).to.equal(amount, "Player should have staked the correct amount");
    });

    it("Should have withdrawn correctly", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).withdraw(amount);

        const balance = await stakingContract.getBalancePlayer(player1.address);
        expect(balance).to.equal(0, "Player should have withdrawn the correct amount");
    });

    it("Should distribute rewards correctly in ETH", async function () {
        const initialStakeAmount = ethers.utils.parseEther("2"); // 2 ETH
        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", initialStakeAmount, {
            value: initialStakeAmount
        });

        const initialEthBalance = await ethers.provider.getBalance(player1.address);

        const rewardAmount = ethers.utils.parseEther("1"); // 1 ETH

        const tx = await stakingContract.reward({ value: rewardAmount });
        await tx.wait();

        const finalEthBalance = await ethers.provider.getBalance(player1.address);

        const expectedBalanceIncrease = ethers.BigNumber.from("999999999999999500");
        expect(finalEthBalance.sub(initialEthBalance)).to.be.closeTo(expectedBalanceIncrease, ethers.BigNumber.from("10000"), "Player should receive correct ETH reward");
    });


    it("Should distribute rewards correctly among stakers", async function () {
        const amountPlayer1 = ethers.utils.parseEther("1");   // 1 ETH
        const amountPlayer2 = ethers.utils.parseEther("2");   // 2 ETH
        const amountPlayer3 = ethers.utils.parseEther("1.5"); // 1.5 ETH
        const amountPlayer4 = ethers.utils.parseEther("0.5"); // 0.5 ETH

        const initialEthBalancePlayer1 = await ethers.provider.getBalance(player1.address);
        const initialEthBalancePlayer2 = await ethers.provider.getBalance(player2.address);
        const initialEthBalancePlayer3 = await ethers.provider.getBalance(player3.address);
        const initialEthBalancePlayer4 = await ethers.provider.getBalance(player4.address);


        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", amountPlayer1, { value: amountPlayer1 });
        await stakingContract.connect(player2).deposit("0x0000000000000000000000000000000000000000", amountPlayer2, { value: amountPlayer2 });
        await stakingContract.connect(player3).deposit("0x0000000000000000000000000000000000000000", amountPlayer3, { value: amountPlayer3 });
        await stakingContract.connect(player4).deposit("0x0000000000000000000000000000000000000000", amountPlayer4, { value: amountPlayer4 });

        const finalEthBalancePlayer1 = await ethers.provider.getBalance(player1.address);
        const finalEthBalancePlayer2 = await ethers.provider.getBalance(player2.address);
        const finalEthBalancePlayer3 = await ethers.provider.getBalance(player3.address);
        const finalEthBalancePlayer4 = await ethers.provider.getBalance(player4.address);

        expect(finalEthBalancePlayer1).to.be.gt(initialEthBalancePlayer1, "Player 1 should gain more ETH than they initially had");
        expect(finalEthBalancePlayer2).to.be.gt(initialEthBalancePlayer2, "Player 2 should gain more ETH than they initially had");
        expect(finalEthBalancePlayer3).to.be.gt(initialEthBalancePlayer3, "Player 3 should gain more ETH than they initially had");
        expect(finalEthBalancePlayer4).to.be.gt(initialEthBalancePlayer4, "Player 4 should gain more ETH than they initially had");
    });

});