// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakingToken} from "contracts/tokens/StakingToken.sol";
import {RewardToken} from "contracts/tokens/RewardToken.sol";
import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct StakeInfo {
        uint256 stakeID;
        uint256 amount;
        uint256 depositTime; // Timestamp when the stake was initiated
        uint256 rewardDebt; // To track reward calculation
    }

    struct Stake {
        StakeInfo[] stakes;
        uint256 ethPriceAtDeposit;
        uint256 totalStaked;
    }

    bool internal locked;
    address public owner;
    StakingToken public stakingToken;
    IERC20 public weth;
    RewardToken public rewardToken;
    uint256 public lastUpdateTime;
    uint256 public timePeriod;
    uint256 public stakeStarted;
    uint256 public stakeEnding;
    uint256 public accumulatedRewardPerToken;
    AggregatorV3Interface internal priceFeed;
    uint256 public rewardRate;
    uint256 public totalStaked;
    uint256 public earlyWithdrawalPenalty;
    uint256 public minStakeAmount;
    uint256 public maxStakeAmount;

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address _oracleAddr) {
        _disableInitializers();
        owner = msg.sender;
        stakingToken = new StakingToken(0);
        rewardToken = new RewardToken(1000000);
        rewardRate = 100;
        accumulatedRewardPerToken = 0;
        lastUpdateTime = block.timestamp;
        stakeStarted = block.timestamp;
        stakeEnding = block.timestamp + 10000;
        timePeriod = 10000;
        earlyWithdrawalPenalty = 10;
        minStakeAmount = 0.5 * 10 ** 18;
        maxStakeAmount = 10000 * 10 ** 18;

        priceFeed = AggregatorV3Interface(_oracleAddr);
        weth = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);
    }

    // Modifier
    /**
     * @dev Prevents reentrancy
     */
    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    // Modifier
    /**
     * @dev only owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /// @dev Allows the user to deposit ETH or ERC20 tokens
    /// @param amount to stake.
    function deposit(uint256 amount) external payable noReentrant {
        require(
            amount >= minStakeAmount,
            "Amount must be greater than minimum stake amount"
        );
        require(
            amount <= maxStakeAmount,
            "Amount must be less than maximum stake amount"
        );

        updateReward(msg.sender);

        uint256 ethPriceAtDeposit = getLatestETHPrice();

        if (msg.value > 0) {
            balances[msg.sender] = balances[msg.sender].add(msg.value);
            stakingToken.mint(address(msg.sender), msg.value);
        } else {
            weth.safeTransferFrom(msg.sender, address(this), amount);
            balances[msg.sender] = balances[msg.sender].add(amount);
            stakingToken.mint(address(msg.sender), amount);
        }

        totalStaked = totalStaked.add(amount);
        Stake storage userStake = stakes[msg.sender];
        userStake.stakes.push(
            StakeInfo(userStake.stakes.length, amount, block.timestamp, 0)
        ); // Initialize rewardDebt to 0
        userStake.totalStaked = userStake.totalStaked.add(amount);
        userStake.ethPriceAtDeposit = ethPriceAtDeposit;

        emit Staked(msg.sender, amount);
    }

    /// @dev Allows user to unstake tokens after the correct time period has elapsed
    /// @param amount - the amount to unlock (in wei)
    function withdraw(uint256 amount) external noReentrant {
        require(
            amount <= balances[msg.sender],
            "Not enough funds in stakingToken"
        );

        require(
            amount <= stakingToken.balanceOf(address(msg.sender)),
            "Insufficient staking tokens"
        );

        require(
            block.timestamp.sub(stakeStarted) > timePeriod,
            "Tokens are only available after correct time period"
        );

        updateReward(msg.sender);

        // Burn staking tokens
        stakingToken.burnFrom(msg.sender, amount);

        // Update user's balance
        balances[msg.sender] = balances[msg.sender].sub(amount);

        uint256 ethReceived = amount; // Adjust this based on conversion rate

        payable(msg.sender).transfer(ethReceived);

        Stake storage userStake = stakes[msg.sender];
        uint256 remainingAmount = amount;

        for (uint256 i = 0; i < userStake.stakes.length; i++) {
            StakeInfo storage stakeInfo = userStake.stakes[i];
            if (stakeInfo.amount > 0) {
                if (stakeInfo.amount >= remainingAmount) {
                    stakeInfo.amount = stakeInfo.amount.sub(remainingAmount);
                    break;
                } else {
                    remainingAmount = remainingAmount.sub(stakeInfo.amount);
                    stakeInfo.amount = 0;
                }
            }
        }

        userStake.totalStaked = userStake.totalStaked.sub(amount);
        totalStaked = totalStaked.sub(amount);

        emit Withdrawn(msg.sender, amount);
    }

    /// @dev Allows user to claim reward tokens depending on their staked amount and duration of the stake.
    function claimReward() external noReentrant {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        console.log("final reward:", reward);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function emergencyWithdraw() external noReentrant {
        uint256 amount = stakes[msg.sender].totalStaked;
        uint256 penalty = amount.mul(earlyWithdrawalPenalty).div(100);
        uint256 amountAfterPenalty = amount.sub(penalty);

        stakingToken.burn(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);

        IERC20(stakingToken).safeTransfer(msg.sender, amountAfterPenalty);

        stakes[msg.sender].totalStaked = 0;
        totalStaked = totalStaked.sub(amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }

    function balanceOfStakingToken(
        address account
    ) external view returns (uint256) {
        return stakingToken.balanceOf(account);
    }

    function balanceOfRewardToken(
        address account
    ) external view returns (uint256) {
        return rewardToken.balanceOf(account);
    }

    function totalStakingTokens() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function getBalancePlayer(address account) external view returns (uint256) {
        return balances[account];
    }

    function getReward(address account) external view returns (uint256) {
        return rewards[account];
    }

    function getRewardRate(address account) public view returns (uint256) {
        uint256 currentEthPrice = getLatestETHPrice();
        Stake storage userStake = stakes[account];

        if (userStake.stakes.length == 0) {
            // Handle case where user hasn't staked yet
            return 100; // Or any default value as needed
        }

        // Get details of the first stake
        StakeInfo storage firstStake = userStake.stakes[0];

        // Calculate time since the first deposit in days
        uint256 timeSinceDeposit = (block.timestamp - firstStake.depositTime) /
            1 days;

        // Calculate time multiplier
        uint256 timeMultiplier = (timeSinceDeposit * rewardRate) / 100;

        // Calculate ETH price adjustment
        uint256 ethPriceAdjustment;
        if (currentEthPrice > userStake.ethPriceAtDeposit) {
            ethPriceAdjustment =
                (currentEthPrice * 1000) /
                userStake.ethPriceAtDeposit;
        } else {
            ethPriceAdjustment =
                (userStake.ethPriceAtDeposit * 1000) /
                currentEthPrice;
        }

        // Calculate adjusted reward rate
        uint256 adjustedRewardRate = rewardRate + timeMultiplier;
        adjustedRewardRate = (adjustedRewardRate * ethPriceAdjustment) / 1000;

        return adjustedRewardRate;
    }

    function updateReward(address account) internal {
        if (totalStaked > 0) {
            uint256 elapsed = block.timestamp.sub(lastUpdateTime);

            uint256 currentRewardRate = getRewardRate(account);

            uint256 rewardPerTokenIncrease = elapsed
                .mul(currentRewardRate)
                .mul(1e18)
                .div(totalStaked);

            accumulatedRewardPerToken = accumulatedRewardPerToken.add(
                rewardPerTokenIncrease
            );

            lastUpdateTime = block.timestamp;

            Stake storage userStake = stakes[account];

            for (uint256 i = 0; i < userStake.stakes.length; i++) {
                uint256 userStakeAmount = userStake.stakes[i].amount;
                uint256 userRewardsPerTokenPaid = userRewardPerTokenPaid[
                    account
                ];
                uint256 rewardsPerTokenDifference = accumulatedRewardPerToken
                    .sub(userRewardsPerTokenPaid);
                uint256 userRewardsIncrease = userStakeAmount
                    .mul(rewardsPerTokenDifference)
                    .div(1e18);
                rewards[account] = rewards[account].add(userRewardsIncrease);
                userRewardPerTokenPaid[account] = accumulatedRewardPerToken;
            }
        } else {
            lastUpdateTime = block.timestamp;
        }
    }

    function getLatestETHPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    /// @dev Sets a new early withdrawal penalty
    /// @param _penalty New penalty percentage
    function setEarlyWithdrawalPenalty(uint256 _penalty) external onlyOwner {
        require(_penalty <= 100, "Penalty must be less than or equal to 100");
        earlyWithdrawalPenalty = _penalty;
    }

    /// @dev Sets a new minimum stake amount
    /// @param _minStakeAmount New minimum stake amount
    function setMinStakeAmount(uint256 _minStakeAmount) external onlyOwner {
        minStakeAmount = _minStakeAmount;
    }

    /// @dev Sets a new maximum stake amount
    /// @param _maxStakeAmount New maximum stake amount
    function setMaxStakeAmount(uint256 _maxStakeAmount) external onlyOwner {
        maxStakeAmount = _maxStakeAmount;
    }

    function transferStakingToken(
        address _receiverAddress,
        uint256 amount
    ) external {
        stakingToken.transferFrom(msg.sender, _receiverAddress, amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[_receiverAddress] = balances[_receiverAddress].add(amount);

        Stake storage senderStake = stakes[msg.sender];
        Stake storage receiverStake = stakes[_receiverAddress];

        senderStake.totalStaked = senderStake.totalStaked.sub(amount);
        receiverStake.totalStaked = receiverStake.totalStaked.add(amount);

        uint256 ethPriceAtTransfer = getLatestETHPrice();
        receiverStake.ethPriceAtDeposit = ethPriceAtTransfer;

        uint256 remainingAmount = amount;

        // Adjust the sender's stakes
        for (
            uint256 i = 0;
            i < senderStake.stakes.length && remainingAmount > 0;
            i++
        ) {
            StakeInfo storage stakeInfo = senderStake.stakes[i];
            if (stakeInfo.amount > 0) {
                if (stakeInfo.amount >= remainingAmount) {
                    stakeInfo.amount = stakeInfo.amount.sub(remainingAmount);
                    break;
                } else {
                    remainingAmount = remainingAmount.sub(stakeInfo.amount);
                    stakeInfo.amount = 0;
                }
            }
        }

        // Add a new stake for the receiver
        receiverStake.stakes.push(
            StakeInfo({
                stakeID: receiverStake.stakes.length,
                amount: amount,
                depositTime: block.timestamp,
                rewardDebt: 0
            })
        );

        updateReward(msg.sender);
        updateReward(_receiverAddress);
    }

    receive() external payable {}
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
