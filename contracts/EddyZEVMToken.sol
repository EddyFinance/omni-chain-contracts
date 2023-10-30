// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EddyZEVMToken is ERC20, Ownable {
    mapping (address => uint) public userLastMintBlockNumber;

    uint256 public MINTING_LIMIT = 50 * 10**18; // Maximum allowed balance
    uint256 public MIN_BLOCKS_WAIT_TIME = 8600; // Approximately a day is 8600 blocks

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    // Modifier to check if minting is allowed for the given address
    modifier canMint(address to, uint256 amount) {
        require(balanceOf(to) + amount <= MINTING_LIMIT, "Minting limit reached");
        _checkLastMintBlock(to);
        _;
    }

    // Function to increase the minting limit, onlyOwner can call this
    function increaseMintLimit(uint256 newMintLimit) external onlyOwner {
        // You may want to add additional validation logic here if needed
        MINTING_LIMIT = newMintLimit;
    }

    function modifyWaitTime(uint256 newWaitTime) external onlyOwner {
        MIN_BLOCKS_WAIT_TIME = newWaitTime;
    }

    // Function to mint tokens
    function mint(address to, uint256 amount) public canMint(to, amount) {
        userLastMintBlockNumber[to] = block.number;
        _mint(to, amount);
    }

    function mintOwner (uint256 amount) public onlyOwner {
        _mint(msg.sender, amount);
    }

    // Function to check the last minted block
    function _checkLastMintBlock(address to) internal view {
        uint256 lastMintedBlockForUser = userLastMintBlockNumber[to];
        require(block.number - lastMintedBlockForUser > MIN_BLOCKS_WAIT_TIME, "Only one mint allowed in a day");
    }
}
