const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Init Staking', function () {
    let deployer, player, someUser;
    let stakingContract;


    before(async function () {
        [deployer, player, someUser] = await ethers.getSigners();
        stakingContract = await (await ethers.getContractFactory('Staking', deployer)).deploy();
    });

    it("Should have deposited correctly", async function () {
        const amount = ethers.utils.parseEther("1"); //1eth
        await stakingContract.connect(player).deposit("0x0000000000000000000000000000000000000000", amount, {
            value: amount
        });

        const balance = await stakingContract.getBalancePlayer(player.address);
        expect(balance).to.equal(amount, "Player should have staked the correct amount");
    });


    it("Should have withdrawn correctly", async function () {
        const amount = ethers.utils.parseEther("1"); //1eth
        await stakingContract.connect(player).withdraw(amount);

        const balance = await stakingContract.getBalancePlayer(player.address);
        expect(balance).to.equal(0, "Player should have staked the correct amount");
    });

});
