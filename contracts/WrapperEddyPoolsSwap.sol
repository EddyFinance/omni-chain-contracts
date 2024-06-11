// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IWETH.sol";

contract WrapperEddyPoolsSwap {
    using SafeMath  for uint;
    address public owner;
    error NoPriceData();

    uint16 internal constant MAX_DEADLINE = 200;
    address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    address public constant UniswapRouter = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address public constant UniswapFactory = 0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c;
    address public constant ZETA = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address private constant EddyTreasurySafe = 0x3f641963f3D9ADf82D890fd8142313dCec807ba5;

    IPyth pyth;


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    event EddyLiquidityAdded(
        address walletAddress,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 fees,
        int64 tokenPriceUnit1,
        int32 tokenPriceExpo1,
        int64 tokenPriceUnit2,
        int32 tokenPriceExpo2
    );

    event EddyLiquidityRemoved(
        address walletAddress,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountA,
        uint256 amountB,
        uint256 fees,
        int64 tokenPriceUnit1,
        int32 tokenPriceExpo1,
        int64 tokenPriceUnit2,
        int32 tokenPriceExpo2
    );

    event EddySwap(
        address walletAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fees,
        int64 tokenPriceUnit,
        int32 tokenPriceExpo
    );

    struct TokenPrice {
        int64 priceUint;
        int32 expo;
    }

    TokenPrice removeLiqToken1;

    TokenPrice removeLiqToken2;

    TokenPrice addLiqToken1;

    TokenPrice addLiqToken2; 

    uint256 public platformFee;

    mapping(address => bytes32) public addressToFeedId;

    constructor(
        address _pythContractAddress,
        uint256 _platformFee
    ) {
        pyth = IPyth(_pythContractAddress);
        platformFee = _platformFee;
        owner = msg.sender;
    }

    error CantBeIdenticalAddresses();

    error CantBeZeroAddress();

    /// @notice Update the address to feed id
    /// @param feedId The feed id
    /// @param asset The asset address
    function updateAddressToFeedId(bytes32 feedId, address asset) external onlyOwner {
        addressToFeedId[asset] = feedId;
    }

    /// @notice Get the price of the asset from pyth oracle
    /// @param priceUpdate The price update
    /// @param _priceFeed The price feed
    /// @return priceUint The price of the asset
    /// @return expo The exponent of the asset
    function getPythPrice (bytes[] calldata priceUpdate,bytes32 _priceFeed) public payable returns(int64 priceUint, int32 expo) {
        uint fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{ value: fee }(priceUpdate);
        PythStructs.Price memory priceData = pyth.getPrice(_priceFeed);
        priceUint = priceData.price; // 11241 / 8 * 30000000000000 / 10 ** decimals
        expo = priceData.expo; // -8
    }

    /// @notice Sorts the tokens
    /// @param tokenA The first token
    /// @param tokenB The second token
    /// @return token0 The first token
    /// @return token1 The second token
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert CantBeIdenticalAddresses();
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token0 == address(0)) revert CantBeZeroAddress();
    }

    /// @notice Get the pair address
    /// @param factory The factory address
    /// @param tokenA The first token
    /// @param tokenB The second token
    /// @return pair The pair address
    function uniswapv2PairFor(
        address factory,
        address tokenA,
        address tokenB
    ) public pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

    /// @notice Swap tokens for tokens
    /// @param amountIn The amount of token to swap
    /// @param amountOutMin The minimum amount of token to receive
    /// @param path The path of the token to swap
    /// @return amounts The amount of token received

    function swapEddyTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        bytes[] calldata priceUpdate
    ) external payable returns(uint[] memory amounts) {
        require(amountIn > 0, "ZERO SWAP AMOUNT");
        address tokenIn = path[0];

        (int64 priceUint, int32 expo) = getPythPrice(priceUpdate,addressToFeedId[tokenIn]);

        require(IERC20(tokenIn).allowance(msg.sender, address(this)) > amountIn, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER FROM FAILED swapEddyTokensForTokens");

        // Substract fees

        uint256 platformFeesForTx = (amountIn * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(tokenIn, EddyTreasurySafe, platformFeesForTx);

        // Give approval to uniswap
        IERC20(tokenIn).approve(address(UniswapRouter), amountIn - platformFeesForTx);

         amounts = IUniswapV2Router01(
            UniswapRouter
            ).swapExactTokensForTokens(
            amountIn - platformFeesForTx,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

        emit EddySwap(
            msg.sender,
            tokenIn,
            path[path.length - 1],
            amountIn,
            amounts[path.length - 1],
            platformFeesForTx,
            priceUint,
            expo
        );
    }


    /// @notice Swap ETH for tokens
    /// @param amountOutMin The minimum amount of token to receive
    /// @param path The path of the token to swap
    /// @return amounts The amount of token received

    function swapEddyExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        bytes[] calldata priceUpdate,
        uint fee
    ) external payable returns(uint[] memory amounts) {
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION");     

        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        (int64 priceUint, int32 expo) = getPythPrice(priceUpdate, addressToFeedId[tokenIn]);

         amounts = IUniswapV2Router01(
            UniswapRouter
            ).swapExactETHForTokens{value: msg.value - 2 * fee }(
            amountOutMin,
            path,
            address(this),
            block.timestamp + MAX_DEADLINE
        );
        uint256 amountOut = amounts[path.length - 1];

        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(tokenOut, EddyTreasurySafe, platformFeesForTx);

        TransferHelper.safeTransfer(tokenOut, msg.sender, amountOut - platformFeesForTx);

   

        emit EddySwap(
            msg.sender,
            tokenIn,
            tokenOut,
            msg.value,
            amountOut,
            platformFeesForTx,
            priceUint,
            expo
        );

    }

    /// @notice Swap tokens for ETH
    /// @param amountIn The amount of token to swap
    /// @param amountOutMin The minimum amount of token to receive
    /// @param path The path of the token to swap
    /// @return amounts The amount of token received

    function swapEddyExactTokensForEth(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        bytes[] calldata priceUpdate
    ) external payable returns(uint[] memory amounts) {
        require(amountIn > 0, "ZERO_SWAP_AMOUNT swapEddyExactTokensForEth");
        address tokenIn = path[0];

         (int64 priceUint, int32 expo) = getPythPrice(priceUpdate,addressToFeedId[tokenIn]);

        require(IERC20(tokenIn).allowance(msg.sender, address(this)) > amountIn, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "TRANSFER FROM FAILED swapEddyTokensForTokens");

        // Substract fees

        uint256 platformFeesForTx = (amountIn * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(tokenIn, EddyTreasurySafe, platformFeesForTx);

        // Give approval to uniswap
        IERC20(tokenIn).approve(address(UniswapRouter), amountIn - platformFeesForTx);

        amounts = IUniswapV2Router01(
            UniswapRouter
            ).swapExactTokensForETH(
            amountIn - platformFeesForTx,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + MAX_DEADLINE
        );

       
        

        emit EddySwap(
            msg.sender,
            tokenIn,
            path[path.length - 1],
            amountIn,
            amounts[path.length - 1],
            platformFeesForTx,
            priceUint,
            expo
        );

    }

    receive() external payable {}

    fallback() external payable {}

    /// @notice Add liquidity to the pool
    /// @param token The token to add
    /// @param amountTokenDesired The amount of token to add
    /// @param amountTokenMin The minimum amount of token to receive
    /// @param amountETHMin The minimum amount of ETH to receive
    /// @return amountToken The amount of token, amount of ETH and liquidity received
    /// @return amountETH The amount of ETH received
    /// @return liquidity The amount of liquidity received

    function eddyAddLiquidityEth(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        bytes[] calldata priceUpdate,
        uint fee
    ) external payable returns(uint amountToken, uint amountETH, uint liquidity){
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION"); // ETH.ETH

        require(IERC20(token).allowance(msg.sender, address(this)) > amountTokenDesired, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired), "TRANSFER FROM FAILED eddyAddLiquidityEth");

        IERC20(token).approve(address(UniswapRouter), amountTokenDesired);

        (addLiqToken1.priceUint,addLiqToken1.expo) = getPythPrice(priceUpdate,addressToFeedId[WZETA]);

        (addLiqToken2.priceUint,addLiqToken2.expo) = getPythPrice(priceUpdate,addressToFeedId[token]);

        (amountToken,amountETH,liquidity) = IUniswapV2Router01(
            UniswapRouter
        ).addLiquidityETH{ value: msg.value - 2 * fee}(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        // Token minted in the contract
        address pairAddress = uniswapv2PairFor(
            UniswapFactory,
            token,
            WZETA
        );

        uint256 platformFeesForTx = (liquidity * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(pairAddress, EddyTreasurySafe, platformFeesForTx);

        TransferHelper.safeTransfer(pairAddress, msg.sender, liquidity - platformFeesForTx);

        // Transfer any remaining eth to user
        payable(msg.sender).transfer(msg.value - amountETH);

        // Transfer remaining token
        TransferHelper.safeTransfer(token, msg.sender, amountTokenDesired - amountToken);
        {
           

            emit EddyLiquidityAdded(
                msg.sender,
                token,
                WZETA,
                amountToken,
                amountETH,
                liquidity,
                platformFeesForTx,
                addLiqToken1.priceUint,
                addLiqToken1.expo,
                addLiqToken2.priceUint,
                addLiqToken2.expo
            );
            
        }
      
    }


    function eddyRemoveLiquidityEth(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        bytes[] calldata priceUpdate
    ) external payable returns(uint amountToken, uint amountETH){
        require(liquidity > 0, "ZERO_AMOUNT_TRANSACTION");
        {
            // LP address
            address pairAddress = uniswapv2PairFor(
                UniswapFactory,
                token,
                WZETA
            );

            require(IERC20(pairAddress).allowance(msg.sender, address(this)) > liquidity, "INSUFFICIENT ALLOWANCE FOR LP_TOKEN REMOVAL");

            require(IERC20(pairAddress).transferFrom(msg.sender, address(this), liquidity), "TRANSFER FROM FAILED eddyRemoveLiquidityEth");
            
            
            IERC20(pairAddress).approve(address(UniswapRouter), liquidity);

            (removeLiqToken1.priceUint,removeLiqToken1.expo) = getPythPrice(priceUpdate,addressToFeedId[WZETA]);

            (removeLiqToken2.priceUint,removeLiqToken2.expo) = getPythPrice(priceUpdate,addressToFeedId[token]);

        }
       
        (amountToken,amountETH) = IUniswapV2Router01(
            UniswapRouter
        ).removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        uint256 platformFeesForTx = (amountToken * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(token, EddyTreasurySafe, platformFeesForTx);

        TransferHelper.safeTransfer(token, msg.sender, amountToken - platformFeesForTx);

        payable(msg.sender).transfer(amountETH);

       { 
        
            emit EddyLiquidityRemoved(
                msg.sender,
                token,
                WZETA,
                liquidity,
                amountToken,
                amountETH,
                platformFeesForTx,
                removeLiqToken1.priceUint,
                removeLiqToken1.expo,
                removeLiqToken2.priceUint,
                removeLiqToken2.expo
            );

       }

       

    }

    /// @notice Deposit ZETA for WZETA
    /// @return amountOut The amount of WZETA received
    function depositZetaForWZETA(bytes[] calldata priceUpdate,uint fee) external payable returns(uint256 amountOut) {
        
        (int64 priceUint, int32 expo) = getPythPrice(priceUpdate,addressToFeedId[ZETA]);
        
        IWETH9(WZETA).deposit{value: msg.value - 2 * fee}();

        amountOut = IWETH9(WZETA).balanceOf(address(this));

        // Got WETH at this point

        // Fees for eddy
        uint256 platformFeesForTx = (amountOut * platformFee) / 10000; 

        IWETH9(WZETA).transfer(EddyTreasurySafe, platformFeesForTx);

        IWETH9(WZETA).transfer(msg.sender, amountOut - platformFeesForTx);

       


        emit EddySwap(
            msg.sender,
            ZETA,
            WZETA,
            msg.value,
            amountOut,
            platformFeesForTx,
            priceUint,
            expo
        );
    }

    /// @notice Withdraw WZETA for ZETA
    /// @param amountIn The amount of WZETA to withdraw
    /// @return amountOut The amount of ZETA received
    function withdrawWZETA(uint256 amountIn, bytes[] calldata priceUpdate) external payable returns(uint256 amountOut) {

        require(IWETH9(WZETA).allowance(msg.sender, address(this)) > amountIn, "NOT_ENOUGH_ALLOWANCE_WETH");

        (int64 priceUint, int32 expo) = getPythPrice(priceUpdate,addressToFeedId[WZETA]);

        bool sentToContract = IWETH9(WZETA).transferFrom(msg.sender, address(this), amountIn);

        require(sentToContract, "FAILED TO TRANSFER WETH TO CONTRACT");

        IWETH9(WZETA).withdraw(amountIn);

        amountOut = amountIn;

        // Got amountIn ETH
        uint256 platformFeesForTx = (amountOut * platformFee) / 10000; 

        

        (bool sent, ) = payable(EddyTreasurySafe).call{value: platformFeesForTx}("");
        require(sent, "Failed to send Ether to Eddy treasury");

        (bool sentToUser, ) = payable(msg.sender).call{value: amountOut - platformFeesForTx}("");
        require(sentToUser, "Failed to send Ether to User");

        


        emit EddySwap(
            msg.sender,
            WZETA,
            ZETA,
            amountIn,
            amountOut,
            platformFeesForTx,
            priceUint,
            expo
        );

    }

}