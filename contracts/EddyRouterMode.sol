// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IPancakeRouter01.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/SFSRegistry.sol";

contract EddySwapRouterMode is Ownable {

    uint16 internal constant MAX_DEADLINE = 200;
    uint256 public constant chainId = 34443;
    uint256 public slippage;
    // Swap mode router
    address public constant swapRouter = 0xc1e624C810D297FD70eF53B0E08F44FABE468591;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant NATIVE_ETH = 0x000000000000000000000000000000000000800A;
    address public SFS_CONTRACT = 0x8680CEaBcb9b56913c519c069Add6Bc3494B7020;
    IPancakeRouter01 swapRouter01;
    IWETH weth;

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

        swapRouter01 = IPancakeRouter01(swapRouter);

        weth = IWETH(WETH);

        Register sfsContract = Register(SFS_CONTRACT);

        sfsContract.register(msg.sender);
        

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
        IERC20(tokenIn).approve(swapRouter, amountIn);

        uint256[] memory amountsOut = swapRouter01.swapExactTokensForTokens(
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
        uint256[] memory amountsOut = swapRouter01.swapExactETHForTokens{value: msg.value}(
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
            address(swapRouter),
            amountIn
        );

        // Amount in ETH
        uint256[] memory amountsOut = swapRouter01.swapExactTokensForETH(
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

    function depositEthForWETH() external payable returns(uint256 amountOut) {
        
        // Call WETH contract's deposit
        weth.deposit{value: msg.value}();

        amountOut = weth.balanceOf(address(this));

        // Got WETH at this point

        // Fees for eddy
        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%

        weth.transfer(EddyTreasury, platformFeesForTx);

        weth.transfer(msg.sender, amountOut - platformFeesForTx);

        emit EddySwap(
            msg.sender,
            NATIVE_ETH,
            WETH,
            msg.value,
            amountOut,
            platformFeesForTx,
            chainId
        );
    }

    function withdrawWETH(uint256 amountIn) external returns(uint256 amountOut) {

        require(weth.allowance(msg.sender, address(this)) > amountIn, "NOT_ENOUGH_ALLOWANCE_WETH");

        bool sentToContract = weth.transferFrom(msg.sender, address(this), amountIn);

        require(sentToContract, "FAILED TO TRANSFER WETH TO CONTRACT");

        weth.withdraw(amountIn);

        amountOut = amountIn;

        // Got amountIn ETH
        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%

        (bool sent, ) = payable(EddyTreasury).call{value: platformFeesForTx}("");
        require(sent, "Failed to send Ether to Eddy treasury");

        (bool sentToUser, ) = payable(msg.sender).call{value: amountOut - platformFeesForTx}("");
        require(sentToUser, "Failed to send Ether to User");


        emit EddySwap(
            msg.sender,
            WETH,
            NATIVE_ETH,
            amountIn,
            amountOut,
            platformFeesForTx,
            chainId
        );

    }

    receive() external payable {}

    fallback() external payable {}
}
