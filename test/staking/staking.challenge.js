const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Staking Contract', function () {
    let deployer, player1, player2, player3, player4;
    let stakingContract, rewardToken;

    beforeEach(async function () {
        [deployer, player1, player2, player3, player4] = await ethers.getSigners();


        

        const MockV3Aggregator = await ethers.getContractFactory('MockV3Aggregator', deployer);
        mockPriceFeed = await MockV3Aggregator.deploy(ethers.utils.parseUnits("2000", 8)); // Mock price of $2000
        await mockPriceFeed.deployed();

        const Staking = await ethers.getContractFactory('Staking', deployer);
        stakingContract = await Staking.deploy(mockPriceFeed.address);
        await stakingContract.deployed();


        const amountToSend = ethers.utils.parseEther("10");
        await deployer.sendTransaction({
            to: stakingContract.address,
            value: amountToSend
        });


        stakeToken = await ethers.getContractAt("IERC20", await stakingContract.stakingToken());

        rewardToken = await ethers.getContractAt("IERC20", await stakingContract.rewardToken());
    });

    it("Should have deposited correctly", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit( amount, { value: amount });

        const balance = await stakingContract.getBalancePlayer(player1.address);
        expect(balance).to.equal(amount, "Player should have staked the correct amount");
    });

    it("Should have withdrawn correctly", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit( amount, { value: amount });

        // Get the current block timestamp
        const currentBlock = await ethers.provider.getBlock('latest');
        const currentTime = currentBlock.timestamp;

        console.log("Current time before adjustment:", currentTime);

        // Increase time by 5000 seconds
        const newTime = currentTime + 10000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

        await stakingContract.connect(player1).withdraw(amount);

        const balance = await stakingContract.getBalancePlayer(player1.address);
        expect(balance).to.equal(0, "Player should have withdrawn the correct amount");
    });

    it("Should distribute rewards correctly in ETH", async function () {

        const initialStakeAmount = ethers.utils.parseEther("2"); // 2 ETH
        await stakingContract.connect(player1).deposit(initialStakeAmount, { value: initialStakeAmount });

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

        await stakingContract.connect(player1).deposit(amountPlayer1, { value: amountPlayer1 });
        await stakingContract.connect(player2).deposit(amountPlayer2, { value: amountPlayer2 });
        await stakingContract.connect(player3).deposit(amountPlayer3, { value: amountPlayer3 });
        await stakingContract.connect(player4).deposit(amountPlayer4, { value: amountPlayer4 });

        // Get the current block timestamp
        const currentBlock = await ethers.provider.getBlock('latest');
        const currentTime = currentBlock.timestamp;

        console.log("Current time before adjustment:", currentTime);

        // Increase time by 5000 seconds
        const newTime = currentTime + 5000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

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


        console.log(await stakingContract.getLatestETHPrice())

    });

    it("Should transfer tokens correctly", async function () {

        const initialStakeAmount = ethers.utils.parseEther("2"); // 2 ETH
        await stakingContract.connect(player1).deposit(initialStakeAmount, { value: initialStakeAmount });


        const balanceAfterDeposit = await stakingContract.getBalancePlayer(player1.address);
        expect(balanceAfterDeposit).to.be.greaterThan(0, "Player should have withdrawn the correct amount");

        await stakeToken.connect(player1).approve(stakingContract.address, ethers.utils.parseEther("2"));

    
        await stakingContract.connect(player1).transferAllStakingTokenById(player2.address,0);
        

        const balanceAfterTransfer = await stakingContract.getBalancePlayer(player1.address);
        expect(balanceAfterTransfer).to.equal(0, "Player should have withdrawn the correct amount");


        const receiverbalanceAfterTransfer = await stakingContract.getBalancePlayer(player2.address);
        expect(receiverbalanceAfterTransfer).to.equal(initialStakeAmount, "Player should have withdrawn the correct amount");


        // Get the current block timestamp
        const currentBlock = await ethers.provider.getBlock('latest');
        const currentTime = currentBlock.timestamp;

        console.log("Current time before adjustment:", currentTime);

        // Increase time by 5000 seconds
        const newTime = currentTime + 10000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

   
        await stakingContract.connect(player2).withdraw(initialStakeAmount);

        const balance = await stakingContract.getBalancePlayer(player2.address);
 
        expect(balance).to.equal(0, "Player should have withdrawn the correct amount");
    });


    it("Should transfer tokens correctly", async function () {

        const initialStakeAmount = ethers.utils.parseEther("2"); // 2 ETH
        await stakingContract.connect(player1).deposit(initialStakeAmount, { value: initialStakeAmount });
        await stakingContract.connect(player1).deposit(initialStakeAmount, { value: initialStakeAmount });


        const balanceAfterDeposit = await stakingContract.getBalancePlayer(player1.address);
        expect(balanceAfterDeposit).to.be.greaterThan(0, "Player should have withdrawn the correct amount");

        await stakeToken.connect(player1).approve(stakingContract.address, ethers.utils.parseEther("2"));

    
        await stakingContract.connect(player1).transferAllStakingTokenById(player2.address,0);
        

        const balanceAfterTransfer = await stakingContract.getBalancePlayer(player1.address);
        expect(balanceAfterTransfer).to.equal(initialStakeAmount, "Player should have withdrawn the correct amount");


        const receiverbalanceAfterTransfer = await stakingContract.getBalancePlayer(player2.address);
        expect(receiverbalanceAfterTransfer).to.equal(initialStakeAmount, "Player should have withdrawn the correct amount");


        // Get the current block timestamp
        const currentBlock = await ethers.provider.getBlock('latest');
        const currentTime = currentBlock.timestamp;

        console.log("Current time before adjustment:", currentTime);

        // Increase time by 5000 seconds
        const newTime = currentTime + 10000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

   
        await stakingContract.connect(player2).withdraw(initialStakeAmount);

        const balance = await stakingContract.getBalancePlayer(player2.address);
 
        expect(balance).to.equal(0, "Player should have withdrawn the correct amount");
    });


    it("Should fail to withdraw before time period", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit(amount, { value: amount });

        // Attempt to withdraw before time period
        await expect(stakingContract.connect(player1).withdraw(amount))
            .to.be.revertedWith("Tokens are only available after correct time period");
    });


    it("Should fail to claim reward without staking", async function () {
        await expect(stakingContract.connect(player1).claimReward())
            .to.be.revertedWith("No rewards available");
    });


    it("Should fail to deposit more than maximum stake amount", async function () {
        const amount = ethers.utils.parseEther("1001"); // 1001 ETH (more than maxStakeAmount 1000)
        await expect(stakingContract.connect(player1).deposit(amount, { value: amount }))
            .to.be.revertedWith("Amount must be less than maximum stake amount");
    });

    it("Should fail to deposit less than minimum stake amount", async function () {
        const amount = ethers.utils.parseEther("0.1"); // 0.1 ETH (less than minStakeAmount)
        await expect(stakingContract.connect(player1).deposit(amount, { value: amount }))
            .to.be.revertedWith("Amount must be greater than minimum stake amount");
    });


    it("Should fail to withdraw more than staked amount", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit(amount, { value: amount });

        // Attempt to withdraw more than deposited
        const withdrawAmount = ethers.utils.parseEther("2");
        await expect(stakingContract.connect(player1).withdraw(withdrawAmount))
            .to.be.revertedWith("Not enough funds in stakingToken");
    });


    it("Should prevent unauthorized access to reward claim", async function () {
        const amount = ethers.utils.parseEther("1"); // 1 ETH
        await stakingContract.connect(player1).deposit(amount, { value: amount });

        // Increase time by 10000 seconds
        const currentBlock = await ethers.provider.getBlock('latest');
        const newTime = currentBlock.timestamp + 10000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

        // Attempt to claim reward by another player
        await expect(stakingContract.connect(player2).claimReward())
            .to.be.revertedWith("No rewards available");
    });


    it("Should correctly handle multiple deposits and withdrawals", async function () {
        const amount1 = ethers.utils.parseEther("1"); // 1 ETH
        const amount2 = ethers.utils.parseEther("0.5"); // 0.5 ETH
        await stakingContract.connect(player1).deposit(amount1, { value: amount1 });
        await stakingContract.connect(player1).deposit(amount2, { value: amount2 });

        const balanceAfterDeposits = await stakingContract.getBalancePlayer(player1.address);
        expect(balanceAfterDeposits).to.equal(amount1.add(amount2), "Player should have correct total balance after multiple deposits");

        // Increase time by 10000 seconds
        const currentBlock = await ethers.provider.getBlock('latest');
        const newTime = currentBlock.timestamp + 10000;
        await ethers.provider.send("evm_setNextBlockTimestamp", [newTime]);
        await ethers.provider.send("evm_mine", []);

        await stakingContract.connect(player1).withdraw(amount1);

        const balanceAfterWithdrawal = await stakingContract.getBalancePlayer(player1.address);
        expect(balanceAfterWithdrawal).to.equal(amount2, "Player should have correct remaining balance after withdrawal");
    });

    
});
