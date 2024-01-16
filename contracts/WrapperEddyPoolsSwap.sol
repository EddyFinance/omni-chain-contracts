// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrapperEddyPoolsSwap is Ownable {
    error NoPriceData();

    uint16 internal constant MAX_DEADLINE = 200;
    address public immutable WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;

    SystemContract public immutable systemContract;

    event EddyLiquidityAdded(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 fees,
        uint256 dollarValueOfTrade
    );

    event EddyLiquidityRemoved(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountA,
        uint256 amountB,
        uint256 fees,
        uint256 dollarValueOfTrade
    );

    event EddySwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fees,
        uint256 dollarValueOfTrade
    );

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
        address tokenOut = path[path.length - 1];


        require(IZRC20(tokenIn).allowance(msg.sender, address(this)) > amountIn, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IZRC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER FROM FAILED swapEddyTokensForTokens");

        // Substract fees

        uint256 platformFeesForTx = (amountIn * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(tokenIn).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        // Give approval to uniswap
        IZRC20(tokenIn).approve(address(systemContract.uniswapv2Router02Address()), amountIn - platformFeesForTx);

        uint256 uintPriceOfAsset = prices[tokenIn];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amountIn * uintPriceOfAsset);

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
            ).swapExactTokensForTokens(
            amountIn - platformFeesForTx,
            0,
            path,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

        emit EddySwap(
            tokenIn,
            tokenOut,
            amountIn,
            amounts[path.length - 1],
            platformFeesForTx,
            dollarValueOfTrade
        );

        return amounts[path.length - 1];

    }

    function swapEddyExactETHForTokens(
        uint amountOutMin,
        address[] calldata path
    ) external payable returns(uint256) {
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        uint256 platformFeesForTx = (msg.value * platformFee) / 1000; // platformFee = 5 <> 0.5%

        (bool sent, ) = payable(owner()).call{value: platformFeesForTx}("");

        require(sent, "Failed to transfer aZeta to owner");

        uint256 uintPriceOfAsset = prices[tokenIn];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (msg.value * uintPriceOfAsset);

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
            ).swapExactETHForTokens{value: msg.value - platformFeesForTx}(
            0,
            path,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

        emit EddySwap(
            tokenIn,
            tokenOut,
            msg.value,
            amounts[path.length - 1],
            platformFeesForTx,
            dollarValueOfTrade
        );

        return amounts[path.length - 1];

    }

    function swapEddyExactTokensForEth(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path
    ) external returns(uint256) {
        require(amountIn > 0, "ZERO_SWAP_AMOUNT swapEddyExactTokensForEth");
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        require(IZRC20(tokenIn).allowance(msg.sender, address(this)) > amountIn, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IZRC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER FROM FAILED swapEddyTokensForTokens");

        // Substract fees

        uint256 platformFeesForTx = (amountIn * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(tokenIn).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        // Give approval to uniswap
        IZRC20(tokenIn).approve(address(systemContract.uniswapv2Router02Address()), amountIn - platformFeesForTx);

        uint256 uintPriceOfAsset = prices[tokenIn];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amountIn * uintPriceOfAsset);

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
            ).swapExactTokensForETH(
            amountIn - platformFeesForTx,
            0,
            path,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

        emit EddySwap(
            tokenIn,
            tokenOut,
            amountIn,
            amounts[path.length - 1],
            platformFeesForTx,
            dollarValueOfTrade
        );

        return amounts[path.length - 1];

    }

    function eddyAddLiquidityEth(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin
    ) external payable {
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION");

        uint256 platformFeesForTx = (msg.value * platformFee) / 1000; // platformFee = 5 <> 0.5%

        (bool sent, ) = payable(owner()).call{value: platformFeesForTx}("");

        require(sent, "Failed to transfer aZeta to owner");

        require(IZRC20(token).allowance(msg.sender, address(this)) > amountTokenDesired, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IZRC20(token).transferFrom(msg.sender, address(this), amountTokenDesired), "TRANSFER FROM FAILED eddyAddLiquidityEth");

        IZRC20(token).approve(address(systemContract.uniswapv2Router02Address()), amountTokenDesired);


        uint256 uintPriceOfAssetA = prices[token];
        uint256 uintPriceOfAssetB = prices[WZETA];

        if (uintPriceOfAssetA == 0) revert NoPriceData();
        if (uintPriceOfAssetB == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amountTokenDesired * uintPriceOfAssetA) + (msg.value + uintPriceOfAssetB);

        (uint amountToken, uint amountETH, uint liquidity) = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
        ).addLiquidityETH{value: msg.value - platformFeesForTx}(
            token,
            amountTokenDesired,
            0,
            0,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

        (bool sentRemainingEth, ) = payable(msg.sender).call{value: msg.value - platformFeesForTx - amountETH}("");

        require(sentRemainingEth, "Failed to send back users ETH");

        emit EddyLiquidityAdded(
            token,
            WZETA,
            amountToken,
            amountETH,
            liquidity,
            platformFeesForTx,
            dollarValueOfTrade
        );

    }
    function eddyRemoveLiquidityEth(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin
    ) external {
        require(liquidity > 0, "ZERO_AMOUNT_TRANSACTION");
        require(IERC20(token).allowance(msg.sender, address(this)) > liquidity, "INSUFFICIENT ALLOWANCE FOR LP_TOKEN REMOVAL");

        require(IERC20(token).transferFrom(msg.sender, address(this), liquidity), "TRANSFER FROM FAILED eddyRemoveLiquidityEth");

        IERC20(token).approve(address(systemContract.uniswapv2Router02Address()), liquidity);

        (uint amountToken, uint amountETH) = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
        ).removeLiquidityETH(
            token,
            liquidity,
            0,
            0,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        uint256 platformFeesForTx = (amountToken * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(token).transfer(msg.sender, amountToken - platformFeesForTx), "TRANSFER OF ZRC20 FAILED eddyRemoveLiquidityEth");

        (bool sent, ) = payable(msg.sender).call{value: amountETH}("");

        require(sent, "FAILED TO TRANSFER ETH TO USER eddyRemoveLiquidityEth");

        uint256 uintPriceOfAssetA = prices[token];
        uint256 uintPriceOfAssetB = prices[WZETA];

        if (uintPriceOfAssetA == 0) revert NoPriceData();
        if (uintPriceOfAssetB == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amountToken * uintPriceOfAssetA) + (amountETH + uintPriceOfAssetB);

        emit EddyLiquidityRemoved(
            token,
            WZETA,
            liquidity,
            amountToken,
            amountETH,
            platformFeesForTx,
            dollarValueOfTrade
        );

    }

    function updatePriceForAsset(address asset, uint256 price) external onlyOwner {
        prices[asset] = price;
    }

    function updatePlatformFee(uint256 _updatedFee) external onlyOwner {
        platformFee = _updatedFee;
    }
}