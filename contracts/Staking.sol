// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakingToken} from "contracts/tokens/StakingToken.sol";
import {RewardToken} from "contracts/tokens/RewardToken.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Stake {
        uint256 amount;
        uint256 rewardDebt; //todo
    }

    // boolean to preven reentrancy
    bool internal locked;

    // Contract owner
    address public owner;

    // ERC20 contract address
    StakingToken public stakingToken;
    RewardToken public rewardToken;

    uint256 public lastUpdateTime;
    uint256 public timePeriod;
    uint256 public stakeStarted;

    uint256 public accumulatedRewardPerToken;

    uint256 public rewardRate;
    uint256 public totalStaked;

    uint256 public earlyWithdrawalPenalty; // Penalty percentage for early withdrawals
    uint256 public minStakeAmount; // Minimum amount to stake
    uint256 public maxStakeAmount; // Maximum amount to stake

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public balances;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor() {
        _disableInitializers();
        owner = msg.sender;
        stakingToken = new StakingToken(0);
        rewardToken = new RewardToken(1000000);
        rewardRate = 100;
        accumulatedRewardPerToken = 0;
        lastUpdateTime = block.timestamp;
        stakeStarted = block.timestamp;
        timePeriod = 10000;
        earlyWithdrawalPenalty = 10; // 10% penalty for early withdrawals
        minStakeAmount = 0.5 * 10**18; // Minimum 0.5 token to stake
        maxStakeAmount = 10000 * 10**18; // Maximum 10000 tokens to stake
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
    /// @param token, null address to deposit ETH or a ERC20 address.
    /// @param amount to stake.
    function deposit(
        address token,
        uint256 amount
    ) external payable noReentrant {
        require(amount >= minStakeAmount, "Amount must be greater than minimum stake amount");
        require(amount <= maxStakeAmount, "Amount must be less than maximum stake amount");


        if (token == address(0)) {
            // Handle ETH
            require(msg.value == amount, "Incorrect ETH amount sent");
            balances[msg.sender] = balances[msg.sender].add(msg.value);
            stakingToken.mint(address(this), msg.value);
        } else {
            // Handle ERC20 token
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            balances[msg.sender] = balances[msg.sender].add(amount);
            stakingToken.mint(address(this), amount);
        }

        totalStaked = totalStaked.add(amount);
        stakes[msg.sender].amount = stakes[msg.sender].amount.add(amount);
        console.log("amounted:", stakes[msg.sender].amount);
        updateReward(msg.sender);

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
            amount <= stakingToken.balanceOf(address(this)),
            "Insufficient staking tokens"
        );

        require(
            block.timestamp.sub(stakeStarted) > timePeriod,
            "Tokens are only available after correct time period"
        );

        updateReward(msg.sender);

        // Burn staking tokens
        stakingToken.burn(amount);

        // Update user's balance
        balances[msg.sender] = balances[msg.sender].sub(amount);

        // Convert burned tokens to ETH (example: 1 staking token = 1 ETH)
        uint256 ethReceived = amount; // TODO Adjust this based on conversion rate

        // Send ETH to user
        payable(msg.sender).transfer(ethReceived);

        stakes[msg.sender].amount = stakes[msg.sender].amount.sub(amount);
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

    /// @dev Updates the rewards accumulated by an account since the last update.
    /// @param account The account address to update rewards for.
    function updateReward(address account) internal {
        uint256 elapsed = block.timestamp.sub(lastUpdateTime);
        console.log("Elapsed time: ", elapsed);

        uint256 rewardPerTokenIncrease = elapsed.mul(rewardRate).mul(1e18).div(
            totalStaked
        );

        accumulatedRewardPerToken = accumulatedRewardPerToken.add(
            rewardPerTokenIncrease
        );

        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            uint256 userStake = stakes[account].amount;

            uint256 userRewardsPerTokenPaid = userRewardPerTokenPaid[account];

            uint256 rewardsPerTokenDifference = accumulatedRewardPerToken.sub(
                userRewardsPerTokenPaid
            );

            uint256 userRewardsIncrease = userStake
                .mul(rewardsPerTokenDifference)
                .div(1e18);

            rewards[account] = rewards[account].add(userRewardsIncrease);

            userRewardPerTokenPaid[account] = accumulatedRewardPerToken;
        }
    }


    /// @dev Allows user to withdraw staked tokens in case of an emergency
    function emergencyWithdraw() external noReentrant {
         uint256 amount = stakes[msg.sender].amount;
        uint256 penalty = amount.mul(earlyWithdrawalPenalty).div(100);
        uint256 amountAfterPenalty = amount.sub(penalty);

        // Burn staking tokens
        stakingToken.burn(amount);

        // Update user's balance
        balances[msg.sender] = balances[msg.sender].sub(amount);

        // Send the staked amount to user
        IERC20(stakingToken).safeTransfer(msg.sender, amountAfterPenalty);

        stakes[msg.sender].amount = 0;
        totalStaked = totalStaked.sub(amount);

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
    /// @param _playerAddress The player's address to check staked balance for.
    /// @return The staked balance of the player.
    function getBalancePlayer(
        address _playerAddress
    ) external view returns (uint256) {
        return balances[_playerAddress];
    }

    /// @dev Returns the accumulated rewards for a specific player.
    /// @param _playerAddress The player's address to check accumulated rewards for.
    /// @return The accumulated rewards of the player.
    function getReward(address _playerAddress) external view returns (uint256) {
        return rewards[_playerAddress];
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

    receive() external payable {}
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
