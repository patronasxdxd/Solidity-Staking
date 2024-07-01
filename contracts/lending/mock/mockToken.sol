// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract MockToken is ERC20Votes {
    constructor()
        ERC20("MockToken", "MTK")
        ERC20Permit("MockToken")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mockMineBlock() external {
        //mines a block for anvil
    }
}
