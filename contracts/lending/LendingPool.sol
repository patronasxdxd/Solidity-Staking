// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingPool is ILendingPool {
    //Gov token
    //lending/borrowing token = aToken

    mapping(address => Reserve) public reserves;
    mapping(address => mapping(address => Loan)) public loans;
    mapping(address => mapping(address => uint256)) public userCollateral;

    uint256 public constant COLLATERAL_FACTOR = 50; // 50% collateral factor

    event Deposit(address indexed user, uint256 amount, address indexed asset);
    event Withdraw(address indexed user, uint256 amount, address indexed asset);
    event Borrow(address indexed user, uint256 amount, address indexed asset);
    event Repay(address indexed user, uint256 amount, address indexed asset);
    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        uint256 amount,
        address indexed asset
    );

    function deposit(address asset, uint256 amount) external override {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        // loans[msg.sender] = loans[msg.sender];
        userCollateral[msg.sender][asset] += amount; // Update user's collateral balance

        reserves[asset].availableLiquidity += amount;
    }

    function withdraw(address asset, uint256 amount) public override {
        require(
            reserves[asset].availableLiquidity >= amount,
            "Not enough liquidity"
        );
        reserves[asset].availableLiquidity -= amount;
        userCollateral[msg.sender][asset] -= amount; // Update user's collateral balance

        IERC20(asset).transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, asset);
    }

    function borrow(address asset, uint256 amount) external override {
        uint256 collateralValue = (userCollateral[msg.sender][asset] *
            getAssetPrice(asset)) / (10 ** 18); // Assuming asset price is scaled to 18 decimals
        console.log("collateralValue", collateralValue);
        uint256 maxBorrowable = (collateralValue * COLLATERAL_FACTOR) / 100;
        console.log("maxBorrowable", maxBorrowable);

        require(amount <= maxBorrowable, "Insufficient collateral");
        require(
            reserves[asset].availableLiquidity >= amount,
            "Not enough liquidity"
        );

        console.log("before availableLiquidity", reserves[asset].availableLiquidity);
          console.log("before principal",  loans[msg.sender][asset].principal);
            console.log("before interest",  loans[msg.sender][asset].interest);
        reserves[asset].availableLiquidity -= amount;
        loans[msg.sender][asset].principal += amount;
        loans[msg.sender][asset].interest = calculateInterest(
            loans[msg.sender][asset].principal
        );



        console.log("after availableLiquidity", reserves[asset].availableLiquidity);
          console.log("after principal",  loans[msg.sender][asset].principal);
            console.log("after interest ",  loans[msg.sender][asset].interest);

        IERC20(asset).transfer(msg.sender, amount);

        // Implement borrow logic with collateral check
        emit Borrow(msg.sender, amount, asset);
    }

     function repay(address asset, uint256 amount) external override {
        require(loans[msg.sender][asset].principal >= amount, "Repaying more than borrowed");
        loans[msg.sender][asset].principal -= amount;
        loans[msg.sender][asset].interest = calculateInterest(loans[msg.sender][asset].principal);

        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        reserves[asset].availableLiquidity += amount;

        emit Repay(msg.sender, amount, asset);
    }

    function liquidate(
        address borrower,
        address asset,
        uint256 amount
    ) external override {
        // Implement liquidation logic
        emit Liquidation(msg.sender, borrower, amount, asset);
    }

    function getReserveData(
        address asset
    ) external view override returns (Reserve memory) {
        return reserves[asset];
    }

    function getUserData(
        address user,
        address asset
    ) external view override returns (Loan memory) {
        return loans[user][asset];
    }

    function getAssetPrice(address asset) internal view returns (uint256) {
        // Implement oracle call or price fetching logic
        return 1 * 10 ** 18; // Dummy value, assuming 1:1 price ratio for simplicity
    }

    function calculateInterest(
        uint256 principal
    ) internal view returns (uint256) {
        // Implement interest calculation logic
        return principal / 10; // Dummy interest calculation
    }
}
