// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakingToken} from "contracts/tokens/StakingToken.sol";
import {RewardToken} from "contracts/tokens/RewardToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Staking is Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bool internal locked;
    address public owner;

    StakingToken public stakingToken;
    RewardToken public rewardToken;
    uint256 public rewardRate;

    constructor() {
        _disableInitializers();
        owner = msg.sender;
        stakingToken = new StakingToken(1000);
        rewardToken = new RewardToken(1000);
        rewardRate = 1;
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

    mapping(address => uint256) public balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    //0x0000000000000000000000000000000000000000
    // Deposit ETH or ERC20 tokens
    function deposit(address token, uint256 amount)
        external
        payable
        noReentrant
    {
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

        // Burn staking tokens
        stakingToken.burn(amount);

        // Update user's balance
        balances[msg.sender] = balances[msg.sender].sub(amount);

        // Convert burned tokens to ETH (example: 1 staking token = 1 ETH)
        uint256 ethReceived = amount; // Adjust this based on your conversion rate or mechanism

        // Send ETH to user
        payable(msg.sender).transfer(ethReceived);

        emit Withdrawn(msg.sender, amount);
    }

    function stake(uint256 amount) external noReentrant {
        require(
            amount <= stakingToken.balanceOf(msg.sender),
            "Not enough STATE tokens"
        );
    }

    function reward() external noReentrant {
        emit RewardPaid(msg.sender, 100);
    }

    function balanceOfStakingToken(address account)
        external
        view
        returns (uint256)
    {
        return stakingToken.balanceOf(account);
    }

    function balanceOfRewardToken(address account)
        external
        view
        returns (uint256)
    {
        return rewardToken.balanceOf(account);
    }

    function totalStakingTokens() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function getBalancePlayer(address _playerAddress) external view returns (uint256) {
        return balances[_playerAddress];
    }
}

interface IWETH is IERC20, IERC20Metadata {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
