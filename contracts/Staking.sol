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

    bool internal locked;
    address public owner;

    StakingToken public stakingToken;
    RewardToken public rewardToken;
    uint256 public lastUpdateTime;
    uint256 public accumulatedRewardPerToken;

    uint256 public rewardRate;
    address[] public stakers;
    uint256 public totalStaked;

    constructor() {
        _disableInitializers();
        owner = msg.sender;
        stakingToken = new StakingToken(0);
        rewardToken = new RewardToken(1000000); //reward token
        rewardRate = 100;
        accumulatedRewardPerToken = 0;
        lastUpdateTime = block.timestamp;
    }

    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
    }

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Deposit ETH or ERC20 tokens
    function deposit(
        address token,
        uint256 amount
    ) external payable noReentrant {
        require(amount > 0, "Amount must be greater than 0");

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

        if (stakes[msg.sender].amount == 0) {
            stakers.push(msg.sender);
        }

        totalStaked = totalStaked.add(amount);
        stakes[msg.sender].amount = stakes[msg.sender].amount.add(amount);
        console.log("amounted:", stakes[msg.sender].amount);
        updateReward(msg.sender);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external noReentrant {
        require(
            amount <= balances[msg.sender],
            "Not enough funds in stakingToken"
        );

        require(
            amount <= stakingToken.balanceOf(address(this)),
            "Insufficient staking tokens"
        );

        updateReward(msg.sender);

        // Burn staking tokens
        stakingToken.burn(amount);

        // Update user's balance
        balances[msg.sender] = balances[msg.sender].sub(amount);

        // Remove from stakers array if withdrawing all
        if (balances[msg.sender] == 0) {
            _removeFromStakers(msg.sender);
        }

        // Convert burned tokens to ETH (example: 1 staking token = 1 ETH)
        uint256 ethReceived = amount; // TODO Adjust this based on conversion rate

        // Send ETH to user
        payable(msg.sender).transfer(ethReceived);

        stakes[msg.sender].amount = stakes[msg.sender].amount.sub(amount);
        totalStaked = totalStaked.sub(amount);

        emit Withdrawn(msg.sender, amount);
    }

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

    function getBalancePlayer(
        address _playerAddress
    ) external view returns (uint256) {
        return balances[_playerAddress];
    }

    function getReward(address _playerAddress) external view returns (uint256) {
        return rewards[_playerAddress];
    }

    function _removeFromStakers(address _staker) internal {
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakers[i] == _staker) {
                stakers[i] = stakers[stakers.length - 1];
                stakers.pop();
                break;
            }
        }
    }
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
