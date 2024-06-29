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
    }

    struct Stake {
        StakeInfo[] stakes;
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
    uint256 public MAX_REWARD_RATE;

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
        maxStakeAmount = 1000 * 10 ** 18;
        MAX_REWARD_RATE = 150;

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
            StakeInfo(userStake.stakes.length, amount)
        ); 
        userStake.totalStaked = userStake.totalStaked.add(amount);

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
        require(reward > 0, "No rewards available");
        rewards[msg.sender] = 0;
        rewardToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    /// @dev Allows user to withdraw staked tokens in case of an emergency
    function emergencyWithdrawAll() external noReentrant {

        updateReward(msg.sender);
        uint256 amount = stakes[msg.sender].totalStaked;



       require(
            amount <= balances[msg.sender],
            "Not enough funds in stakingToken"
        );

        require(
            amount <= stakingToken.balanceOf(address(msg.sender)),
            "Insufficient staking tokens"
        );


        uint256 penalty = amount.mul(earlyWithdrawalPenalty).div(100);
        uint256 amountAfterPenalty = amount.sub(penalty);


        stakingToken.burnFrom(msg.sender, amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        
        payable(msg.sender).transfer(amountAfterPenalty);

        if (penalty > 0) {
            payable(address(this)).transfer(penalty);
         }

        delete stakes[msg.sender];

        emit EmergencyWithdraw(msg.sender, amount);
    }

    /// @dev Returns the balance of staking tokens held by an account.
    /// @param account The account address to check balance for.
    /// @return The balance of staking tokens.
    function balanceOfStakingToken(
        address account
    ) external view returns (uint256) {
        return stakingToken.balanceOf(account);
    }

    /// @dev Returns the balance of reward tokens held by an account.
    /// @param account The account address to check balance for.
    /// @return The balance of reward tokens.
    function balanceOfRewardToken(
        address account
    ) external view returns (uint256) {
        return rewardToken.balanceOf(account);
    }

    /// @dev Returns the total amount of staking tokens held by the staking contract.
    /// @return The total balance of staking tokens.
    function totalStakingTokens() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    /// @dev Returns the staked balance of a specific player.
    /// @param account The player's address to check staked balance for.
    /// @return The staked balance of the player.
    function getBalancePlayer(address account) external view returns (uint256) {
        return balances[account];
    }

    function getReward(address account) external view returns (uint256) {
        return rewards[account];
    }

    function updateReward(address account) internal {
        if (totalStaked > 0) {
            uint256 elapsed = block.timestamp.sub(lastUpdateTime);

            uint256 rewardPerTokenIncrease = elapsed
                .mul(rewardRate)
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

    function transferAllStakingTokenById(
        address _receiverAddress,
        uint256 _stakeId
    ) external {
        Stake storage senderStake = stakes[msg.sender];
        Stake storage receiverStake = stakes[_receiverAddress];

        uint256 length = senderStake.stakes.length;
        bool found = false;
        uint256 amount = 0;

        for (uint256 i = 0; i < senderStake.stakes.length; i++) {
            if (senderStake.stakes[i].stakeID == _stakeId) {
                found = true;
                amount = senderStake.stakes[i].amount;
                receiverStake.stakes.push(senderStake.stakes[i]);

                for (uint256 j = i; j < length - 1; j++) {
                    senderStake.stakes[j] = senderStake.stakes[j + 1];
                }
                senderStake.stakes.pop();

                break;
            }
        }

        stakingToken.transferFrom(msg.sender, _receiverAddress, amount);

        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[_receiverAddress] = balances[_receiverAddress].add(amount);

        senderStake.totalStaked = senderStake.totalStaked.sub(amount);
        receiverStake.totalStaked = receiverStake.totalStaked.add(amount);

        updateReward(msg.sender);
        updateReward(_receiverAddress);
    }

    function adjustStakeAmounts() public onlyOwner {
    uint256 currentETHPrice = getLatestETHPrice();
        if (currentETHPrice < 2000 * 1e8) { 
            minStakeAmount = 0.25 * 10 ** 18; 
            maxStakeAmount = 500 * 10 ** 18;  
        } else {
            minStakeAmount = 0.5 * 10 ** 18;  
            maxStakeAmount = 1000 * 10 ** 18; 
        }
}


    receive() external payable {}
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
