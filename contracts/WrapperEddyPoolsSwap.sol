// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrapperEddyPoolsSwap is Ownable {
    uint16 internal constant MAX_DEADLINE = 200;

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
        address[] calldata path
    ) external returns(uint256) {
        require(amountIn > 0, "ZERO SWAP AMOUNT");
        address tokenIn = path[0];

        require(IZRC20(tokenIn).allowance(msg.sender, address(this)) > amountIn, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IZRC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER FROM FAILED swapEddyTokensForTokens");

        // Substract fees

        uint256 platformFeesForTx = (amountIn * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(tokenIn).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
            ).swapExactTokensForTokens(
            amountIn - platformFeesForTx,
            0,
            path,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

        return amounts[path.length - 1];

    }

    function swapEddyExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {}

    function swapEddyExactTokensForEth(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {}

    function eddyAddLiquidityEth(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external {}
    function eddyRemoveLiquidityEth(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external {}

    function updatePriceForAsset(address asset, uint256 price) external onlyOwner {
        prices[asset] = price;
    }

    function updatePlatformFee(uint256 _updatedFee) external onlyOwner {
        platformFee = _updatedFee;
    }
}