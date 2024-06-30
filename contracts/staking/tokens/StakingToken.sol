// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    constructor(uint256 initialSupply) ERC20("StakingToken", "STK") Ownable() {
        _mint(msg.sender, initialSupply);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
        emit Minted(account, amount);

    }

      function burnFrom(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

      function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    function safeTransfer(address to, uint256 amount) external onlyOwner {
        _safeTransfer(msg.sender, to, amount);
    }

     function safeTransferFrom(address from, address to, uint256 amount) external onlyOwner {
        _safeTransfer(from, to, amount);
    }

    function _safeTransfer(address from, address to, uint256 amount) internal {
        // Use SafeERC20 to perform the transfer
        IERC20(address(from)).safeTransfer(to, amount);
    }

    event Minted(address indexed account, uint256 amount);

}
