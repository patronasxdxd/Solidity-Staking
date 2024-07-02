// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay is how long you have to wait before executing
    // proposers is the list of addresses that can propose
    // executors is the list of addresses that can execute
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors) {

    }


     // Getter function for current block timestamp
    function getCurrentBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    // Getter function for the timestamp of an operation
    function getOperationTimestamp() public view returns (uint256) {
        return getTemp();
    }
    

       // Getter function for the timestamp of an operation
    function getID() public view returns (bytes32) {
        return getTempId();
    }
    
    
    // Getter function for _DONE_TIMESTAMP
    function getDoneTimestamp() public pure returns (uint256) {
        return _DONE_TIMESTAMP;
    }
}