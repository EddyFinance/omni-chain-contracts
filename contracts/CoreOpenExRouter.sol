// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IOpenExRouter.sol";
import "./interfaces/IWETH.sol";

contract CoreOpenExRouter is Ownable {

    uint16 internal constant MAX_DEADLINE = 200;
    uint256 public constant chainId = 34443;
    uint256 public slippage;
    // Swap mode router
    address public constant openExRouterAddr = 0xc885C4a8B112B8a165338566421c685024Ec44F9;
    IOpenExRouter openExRouter;

    address private constant EddyTreasury = 0xD8242f33A3CFf8542a3F71196eB2e63a26E6059F;

    event EddySwap(
        address walletAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fees,
        uint256 chainId
    );

    uint256 public platformFee;

    constructor(uint256 _platformFee) {
        platformFee = _platformFee;

        openExRouter = IOpenExRouter(openExRouterAddr);

    }

    function updatePlatformFee(uint256 _updatedFee) external onlyOwner {
        platformFee = _updatedFee;
    }

    function swapEddyTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256) {
        require(amountIn > 0, "ZERO SWAP AMOUNT");
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        require(
            IERC20(tokenIn).allowance(msg.sender, address(this)) > amountIn,
            "INSUFFICIENT ALLOWANCE FOR TOKEN_IN"
        );

        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "TRANSFER FROM FAILED swapEddyTokensForTokens"
        );

        // Give approval to router
        IERC20(tokenIn).approve(address(openExRouterAddr), amountIn);

        uint256[] memory amountsOut = openExRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );
        uint256 amountOut = amountsOut[amountsOut.length - 1];

        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(
            tokenOut,
            EddyTreasury,
            platformFeesForTx
        );

        TransferHelper.safeTransfer(
            tokenOut,
            to,
            amountOut - platformFeesForTx
        );

        emit EddySwap(
            to,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            platformFeesForTx,
            chainId
        );

        return amountOut;
    }

    function swapEddyExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256) {
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION");
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        // Swap all the Core
        uint256[] memory amountsOut = openExRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 amountOut = amountsOut[amountsOut.length - 1];

        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(
            tokenOut,
            EddyTreasury,
            platformFeesForTx
        );

        TransferHelper.safeTransfer(
            tokenOut,
            to,
            amountOut - platformFeesForTx
        );

        emit EddySwap(
            to,
            tokenIn,
            tokenOut,
            msg.value,
            amountOut,
            platformFeesForTx,
            chainId
        );

        return amountOut;
    }

    function swapEddyExactTokensForEth(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256) {
        require(amountIn > 0, "ZERO_SWAP_AMOUNT swapEddyExactTokensForEth");

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        require(
            IERC20(tokenIn).allowance(msg.sender, address(this)) > amountIn,
            "INSUFFICIENT ALLOWANCE FOR TOKEN_IN"
        );

        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "TRANSFER FROM FAILED swapEddyTokensForTokens"
        );

        // Give approval to swapRouter
        IERC20(tokenIn).approve(
            address(openExRouterAddr),
            amountIn
        );

        // Amount in ETH
        uint256[] memory amountsOut = openExRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 amountOut = amountsOut[amountsOut.length - 1];

        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%
        {

            (bool sent, ) = payable(EddyTreasury).call{value: platformFeesForTx}("");
            require(sent, "Failed to send Ether to Eddy treasury");

            (bool sentToUser, ) = payable(msg.sender).call{value: amountOut - platformFeesForTx}("");
            require(sentToUser, "Failed to send Ether to User");
        }


        emit EddySwap(
            to,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            platformFeesForTx,
            chainId
        );

        return amountOut;
    }

    function transferEthToOwner() external onlyOwner {
        uint256 ethBalance = address(this).balance;
        (bool sent, ) = payable(msg.sender).call{value: ethBalance}("");
        require(sent, "Failed to send Ether to owner");
    }

    function transferERC20ToOwner(address token) external onlyOwner {
        uint256 tokenAmount = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransfer(
            token,
            msg.sender,
            tokenAmount
        );
    }

    receive() external payable {}

    fallback() external payable {}
}
