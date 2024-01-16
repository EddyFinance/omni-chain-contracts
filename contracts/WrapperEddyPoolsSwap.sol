// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrapperEddyPoolsSwap is Ownable {
    SystemContract public immutable systemContract;

    uint256 public platformFee;
    mapping(address => uint256) public prices;

    constructor(
        address systemContractAddress,
        uint256 _platformFee
    ) {
        systemContract = SystemContract(systemContractAddress);
        platformFee = _platformFee;
    }

    function swapEddyTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {

    }

    function updatePriceForAsset(address asset, uint256 price) external onlyOwner {
        prices[asset] = price;
    }

    function updatePlatformFee(uint256 _updatedFee) external onlyOwner {
        platformFee = _updatedFee;
    }
}