// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakingToken} from "contracts/tokens/StakingToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bool internal locked;
    address public owner;

    StakingToken public stakingToken;
    uint256 public rewardRate;
    address[] public stakers;

    constructor() {
        _disableInitializers();
        owner = msg.sender;
        stakingToken = new StakingToken(1000);
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

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

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

        // Remove from stakers array if withdrawing all
        if (balances[msg.sender] == 0) {
            _removeFromStakers(msg.sender);
        }

        // Convert burned tokens to ETH (example: 1 staking token = 1 ETH)
        uint256 ethReceived = amount; // TODO Adjust this based on conversion rate

        // Send ETH to user
        payable(msg.sender).transfer(ethReceived);

        emit Withdrawn(msg.sender, amount);
    }

    function reward() external payable noReentrant {
        uint256 totalBalance = stakingToken.balanceOf(address(this));
        require(totalBalance > 0, "No staking tokens to distribute rewards");

        uint256 ethReceived = msg.value;

        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 stakerBalance = balances[staker];
            if (stakerBalance > 0) {
                uint256 ethToSend = ethReceived.mul(stakerBalance).div(
                    totalBalance
                );
                payable(staker).transfer(ethToSend);
            }
        }
    }

    function balanceOfStakingToken(
        address account
    ) external view returns (uint256) {
        return stakingToken.balanceOf(account);
    }

    function totalStakingTokens() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function getBalancePlayer(
        address _playerAddress
    ) external view returns (uint256) {
        return balances[_playerAddress];
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
