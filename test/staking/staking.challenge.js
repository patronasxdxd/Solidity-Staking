const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Staking Contract', function () {
    let deployer, player1, player2, player3, player4;
    let stakingContract, rewardToken;

    beforeEach(async function () {
        [deployer, player1, player2, player3, player4] = await ethers.getSigners();
        const Staking = await ethers.getContractFactory('Staking', deployer);
        stakingContract = await Staking.deploy();
        await stakingContract.deployed();

       const amountToSend = ethers.utils.parseEther("10");
        await deployer.sendTransaction({
            to: stakingContract.address,
            value: amountToSend
        });

        rewardToken = await ethers.getContractAt("IERC20", await stakingContract.rewardToken());
    });

    it("Should have deposited correctly", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", amount, { value: amount });

        const balance = await stakingContract.getBalancePlayer(player1.address);
        expect(balance).to.equal(amount, "Player should have staked the correct amount");
    });

    it("Should have withdrawn correctly", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", amount, { value: amount });
        await stakingContract.connect(player1).withdraw(amount);

        const balance = await stakingContract.getBalancePlayer(player1.address);
        expect(balance).to.equal(0, "Player should have withdrawn the correct amount");
    });

    it("Should distribute rewards correctly in ETH", async function () {

        const initialStakeAmount = ethers.utils.parseEther("2"); // 2 ETH
        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", initialStakeAmount, { value: initialStakeAmount });

        // Get the current block timestamp
        const currentBlock = await ethers.provider.getBlock('latest');
        const currentTime = currentBlock.timestamp;
        
        console.log("Current time before adjustment:", currentTime);
        
        // Increase time by 5000 seconds
        const newTime = currentTime + 5000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

        const tx = await stakingContract.connect(player1).claimReward();
        await tx.wait();

        const rewardTokensPlayer1 = await stakingContract.balanceOfRewardToken(player1.address)


        // Assert that player's ETH balance has increased within an acceptable margin
        const expectedRewardTokens = ethers.BigNumber.from("500000");
        expect(expectedRewardTokens).to.be.closeTo(rewardTokensPlayer1, 1000, "Player should receive correct ETH reward");
    });

    it("Should distribute rewards correctly among stakers", async function () {
        // Stake by multiple users
        const amountPlayer1 = ethers.utils.parseEther("1");   // 1 ETH
        const amountPlayer2 = ethers.utils.parseEther("3");   // 3 ETH
        const amountPlayer3 = ethers.utils.parseEther("2");   // 2 ETH
        const amountPlayer4 = ethers.utils.parseEther("0.5"); // 0.5 ETH

        await stakingContract.connect(player1).deposit("0x0000000000000000000000000000000000000000", amountPlayer1, { value: amountPlayer1 });
        await stakingContract.connect(player2).deposit("0x0000000000000000000000000000000000000000", amountPlayer2, { value: amountPlayer2 });
        await stakingContract.connect(player3).deposit("0x0000000000000000000000000000000000000000", amountPlayer3, { value: amountPlayer3 });
        await stakingContract.connect(player4).deposit("0x0000000000000000000000000000000000000000", amountPlayer4, { value: amountPlayer4 });

        // Get the current block timestamp
        const currentBlock = await ethers.provider.getBlock('latest');
        const currentTime = currentBlock.timestamp;
        
        console.log("Current time before adjustment:", currentTime);
        
        // Increase time by 5000 seconds
        const newTime = currentTime + 5000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);


 
        // Claim rewards for each player
        await stakingContract.connect(player1).claimReward();
        await stakingContract.connect(player2).claimReward();
        await stakingContract.connect(player3).claimReward();
        await stakingContract.connect(player4).claimReward();


        const rewardTokensPlayer1 = await stakingContract.balanceOfRewardToken(player1.address)
        const rewardTokensPlayer2 = await stakingContract.balanceOfRewardToken(player2.address)
        const rewardTokensPlayer3 = await stakingContract.balanceOfRewardToken(player3.address)
        const rewardTokensPlayer4 = await stakingContract.balanceOfRewardToken(player4.address)


        console.log(rewardTokensPlayer1)
        console.log(rewardTokensPlayer2)
        console.log(rewardTokensPlayer3)
        console.log(rewardTokensPlayer4)



        // // Calculate expected rewards
        // const totalStaked = amountPlayer1.add(amountPlayer2).add(amountPlayer3).add(amountPlayer4);
        // const rewardPerToken = rewardAmount.div(totalStaked);
        // const rewardPlayer1 = rewardPerToken.mul(amountPlayer1);
        // const rewardPlayer2 = rewardPerToken.mul(amountPlayer2);
        // const rewardPlayer3 = rewardPerToken.mul(amountPlayer3);
        // const rewardPlayer4 = rewardPerToken.mul(amountPlayer4);

        // console.log(rewardPlayer1)
        // console.log(rewardPlayer2)
        // console.log(rewardPlayer3)
        // console.log(rewardPlayer4)

        // // Assert that each player's reward is as expected
        // // expect(finalEthBalancePlayer1.sub(initialEthBalancePlayer1)).to.be.closeTo(rewardPlayer1, ethers.BigNumber.from("10000"), "Player 1 should receive correct ETH reward");
        // // expect(finalEthBalancePlayer2.sub(initialEthBalancePlayer2)).to.be.closeTo(rewardPlayer2, ethers.BigNumber.from("10000"), "Player 2 should receive correct ETH reward");
        // // expect(finalEthBalancePlayer3.sub(initialEthBalancePlayer3)).to.be.closeTo(rewardPlayer3, ethers.BigNumber.from("10000"), "Player 3 should receive correct ETH reward");
        // // expect(finalEthBalancePlayer4.sub(initialEthBalancePlayer4)).to.be.closeTo(rewardPlayer4, ethers.BigNumber.from("10000"), "Player 4 should receive correct ETH reward");
    });

});
