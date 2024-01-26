// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WrapperEddyPoolsSwap is Ownable {
    error NoPriceData();

    uint16 internal constant MAX_DEADLINE = 200;
    address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;

    IPyth pyth;

    SystemContract public immutable systemContract;

    event EddyLiquidityAdded(
        address walletAddress,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 fees,
        int64 priceUintA,
        int32 expoA,
        int64 priceUintB,
        int32 expoB
    );

    event EddyLiquidityRemoved(
        address walletAddress,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountA,
        uint256 amountB,
        uint256 fees,
        int64 priceUintA,
        int32 expoA,
        int64 priceUintB,
        int32 expoB
    );

    event EddySwap(
        address walletAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fees,
        int64 priceUint,
        int32 expo
    );

    uint256 public platformFee;
    mapping(address => int64) public prices;

    mapping(address => bytes32) public addressToTokenId;

    constructor(
        address systemContractAddress,
        address _pythContractAddress,
        uint256 _platformFee
    ) {
        systemContract = SystemContract(systemContractAddress);
        pyth = IPyth(_pythContractAddress);
        platformFee = _platformFee;
    }

    error CantBeIdenticalAddresses();

    error CantBeZeroAddress();

    function updateAddressToTokenId(bytes32 tokenId, address asset) external onlyOwner {
        addressToTokenId[asset] = tokenId;
    }

    function getPriceOfToken(address token) internal view returns(int64 priceUint, int32 expo) {
        PythStructs.Price memory priceData = pyth.getPrice(addressToTokenId[token]);
        priceUint = priceData.price;
        expo = priceData.expo;
    }

    function updatePriceForAsset(address asset, int64 price) external onlyOwner {
        prices[asset] = price;
    }

    function updatePlatformFee(uint256 _updatedFee) external onlyOwner {
        platformFee = _updatedFee;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
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

    // calculates the CREATE2 address for a pair without making any external calls
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

        (int64 priceUint, int32 expo) = getPriceOfToken(tokenIn);

        if (priceUint == 0) revert NoPriceData();

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
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
            tokenOut,
            amountIn,
            amounts[path.length - 1],
            platformFeesForTx,
            priceUint,
            expo
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

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
            ).swapExactETHForTokens{value: msg.value }(
            amountOutMin,
            path,
            address(this),
            block.timestamp + MAX_DEADLINE
        );
        uint256 amountOut = amounts[path.length - 1];

        uint256 platformFeesForTx = (amountOut * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(tokenOut).transfer(owner(), platformFeesForTx), "TRANSFER OF ZRC20 FAILED TO OWNER()");

        require(IZRC20(tokenOut).transfer(msg.sender, amountOut - platformFeesForTx), "TRANSFER OF ZRC20 FAILED TO USER");

        emit EddySwap(
            msg.sender,
            tokenIn,
            tokenOut,
            msg.value,
            amountOut,
            platformFeesForTx,
            prices[WZETA],
            0
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

        (int64 priceUint, int32 expo) = getPriceOfToken(tokenIn);

        if (priceUint == 0) revert NoPriceData();

        uint256[] memory amounts = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
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
            tokenOut,
            amountIn,
            amounts[path.length - 1],
            platformFeesForTx,
            priceUint,
            expo
        );

        return amounts[path.length - 1];

    }

    receive() external payable {}

    fallback() external payable {}

    function eddyAddLiquidityEth(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin
    ) external payable {
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION");

        require(IZRC20(token).allowance(msg.sender, address(this)) > amountTokenDesired, "INSUFFICIENT ALLOWANCE FOR TOKEN_IN");

        require(IZRC20(token).transferFrom(msg.sender, address(this), amountTokenDesired), "TRANSFER FROM FAILED eddyAddLiquidityEth");

        IZRC20(token).approve(address(systemContract.uniswapv2Router02Address()), amountTokenDesired);


        (int64 priceUintA, int32 expoA) = getPriceOfToken(token);

        if (priceUintA == 0) revert NoPriceData();

        (uint amountToken, uint amountETH, uint liquidity) = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
        ).addLiquidityETH{ value: msg.value }(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        // Token minted in the contract
        address pairAddress = uniswapv2PairFor(
            systemContract.uniswapv2FactoryAddress(),
            token,
            WZETA
        );

        uint256 platformFeesForTx = (liquidity * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IERC20(pairAddress).transfer(owner(), platformFeesForTx), "FAILED TO TRANSFER FEES TO OWNER()");

        require(IERC20(pairAddress).transfer(msg.sender, liquidity - platformFeesForTx), "FAILED TO TRANSFER FEES TO OWNER()");

        // Transfer any remaining eth to user
        (bool sent, ) = payable(msg.sender).call{ value: msg.value - amountETH }("");

        require(sent, "FAILED TO TRANSFER REMAINING ETH TO USER");

        emit EddyLiquidityAdded(
            msg.sender,
            token,
            WZETA,
            amountToken,
            amountETH,
            liquidity,
            platformFeesForTx,
            priceUintA,
            expoA,
            prices[WZETA],
            0
        );

    }
    function eddyRemoveLiquidityEth(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin
    ) external {
        require(liquidity > 0, "ZERO_AMOUNT_TRANSACTION");

        // LP address
        address pairAddress = uniswapv2PairFor(
            systemContract.uniswapv2FactoryAddress(),
            token,
            WZETA
        );

        require(IERC20(pairAddress).allowance(msg.sender, address(this)) > liquidity, "INSUFFICIENT ALLOWANCE FOR LP_TOKEN REMOVAL");

        require(IERC20(pairAddress).transferFrom(msg.sender, address(this), liquidity), "TRANSFER FROM FAILED eddyRemoveLiquidityEth");

        
        IERC20(pairAddress).approve(address(systemContract.uniswapv2Router02Address()), liquidity);

        (uint amountToken, uint amountETH) = IUniswapV2Router01(
            systemContract.uniswapv2Router02Address()
        ).removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        uint256 platformFeesForTx = (amountToken * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(token).transfer(owner(), platformFeesForTx), "FAILED TO TRANSFER TOKENS TO OWNER()");

        require(IZRC20(token).transfer(msg.sender, amountToken - platformFeesForTx), "TRANSFER OF ZRC20 FAILED eddyRemoveLiquidityEth");

        (bool sent, ) = payable(msg.sender).call{value: amountETH}("");

        require(sent, "FAILED TO TRANSFER ETH TO USER eddyRemoveLiquidityEth");

        (int64 priceUintA, int32 expoA) = getPriceOfToken(token);

        if (priceUintA == 0) revert NoPriceData();

        emit EddyLiquidityRemoved(
            msg.sender,
            token,
            WZETA,
            liquidity,
            amountToken,
            amountETH,
            platformFeesForTx,
            priceUintA,
            expoA,
            prices[WZETA],
            0
        );

    }

}