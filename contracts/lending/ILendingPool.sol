// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./GovernorContract.sol";

interface ILendingPool {
    struct Reserve {
        uint256 availableLiquidity;
        uint256 totalDebt;
        uint256 borrowRate;
        uint256 supplyRate;
    }

    struct Loan {
        uint256 principal;
        uint256 interest;
    }

    function deposit(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function borrow(address asset, uint256 amount) external;
    function repay(address asset, uint256 amount) external;
    function liquidate(address borrower, address asset, uint256 amount) external;
    function getReserveData(address asset) external view returns (Reserve memory);
    function getUserData(address user, address asset) external view returns (Loan memory);
    function createGovernorProposal(string memory description) external;
    function voteGovernorProposal(uint256 proposalId, bool support) external;
    function executeGovernorProposal(uint256 proposalId) external;
    function getGovernorProposal(uint256 proposalId) external view returns (GovernorContract.Proposal memory);



}