// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "hardhat/console.sol";
import "./interfaces/IWZETA.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/TransferHelper.sol";

// 1 - Pyth integrate
// 2 - Dynamic slippage
// 3 - USDC/USDT tokens integrate

contract EddyTransferNativeAssets is zContract, Ownable {
    error SenderNotSystemContract();
    error WrongAmount();
    error NoPriceData();
    error IdenticalAddresses();
    error ZeroAddress();

    IPyth pyth;

    event EddyCrossChainSwap(
        address zrc20,
        address targetZRC20,
        uint256 amount,
        uint256 outputAmount,
        address walletAddress,
        uint256 fees
    );

    SystemContract public immutable systemContract;

    // Testnet BTC(Zeth)
    address public constant BTC_ZETH = 0x13A0c5930C028511Dc02665E7285134B6d11A5f4;
    address public constant AZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    address public constant UniswapRouter = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address public constant UniswapFactory = 0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c;
    uint16 internal constant MAX_DEADLINE = 200;
    IWZETA public immutable WZETA;

    address private constant EddyTreasurySafe = 0x3f641963f3D9ADf82D890fd8142313dCec807ba5;

    uint256 public platformFee;
    uint256 public slippage;

    mapping(address => int64) public prices;

    mapping(address => bytes32) public addressToTokenId;

    constructor(
        address systemContractAddress,
        address wrappedZetaToken,
        address _pythContractAddress,
        uint256 _platformFee,
        uint256 _slippage
    ) {
        systemContract = SystemContract(systemContractAddress);
        WZETA = IWZETA(wrappedZetaToken);
        pyth = IPyth(_pythContractAddress);
        platformFee = _platformFee;
        slippage = _slippage;
    }

    function _getRecipient(bytes calldata message) internal pure returns (bytes32 recipient) {
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 0);
        recipient = BytesHelperLib.addressToBytes(recipientAddr);
    }

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

    function updateSlippage(uint256 _slippage) external onlyOwner {
        slippage = _slippage;
    }

    function bytesToBech32Bytes(
        bytes calldata data,
        uint256 offset
    ) internal pure returns (bytes memory) {
        bytes memory bech32Bytes = new bytes(42);
        for (uint i = 0; i < 42; i++) {
            bech32Bytes[i] = data[i + offset];
        }

        return bech32Bytes;
    }

    function _swapAndSendERC20Tokens(
        address targetZRC20,
        address gasZRC20,
        uint256 gasFee,
        bytes32 receipient,
        uint256 targetAmount,
        address userEvmAddress
    ) internal returns(uint256 amountsOut) {

        // Get amountOut for Input gasToken
        uint[] memory amountsQuote = UniswapV2Library.getAmountsIn(
            UniswapFactory,
            gasFee,
            getPathForTokens(targetZRC20, gasZRC20) // [gasAmount ,zetaAmount,usdcAmount]
        );

        console.log(amountsQuote[0], "amountsQuote =====>");

        uint amountInMax = (amountsQuote[0]) + (slippage * amountsQuote[0]) / 1000;

        console.log(amountInMax, "amountInMax =====>");

        // Give approval to uniswap
        IZRC20(targetZRC20).approve(address(UniswapRouter), amountInMax);

        // Swap gasFees for targetZRC20
        uint[] memory amounts = IUniswapV2Router01(UniswapRouter)
            .swapTokensForExactTokens(
                gasFee, // Amount of gas token required
                amountInMax,
                getPathForTokens(targetZRC20, gasZRC20),
                address(this),
                block.timestamp + MAX_DEADLINE
        );

        console.log(amounts[0], amounts[1], amounts[2], "amounts _swapAndSendERC20Tokens");

        require(IZRC20(gasZRC20).balanceOf(address(this)) >= gasFee, "INSUFFICIENT_GAS_FOR_WITHDRAW");

        IZRC20(gasZRC20).approve(targetZRC20, gasFee);

        require(targetAmount - amountInMax > 0, "INSUFFICIENT_AMOUNT_FOR_WITHDRAW");

        console.log("withdrawing", targetAmount - amountInMax);

        IZRC20(targetZRC20).withdraw(
            abi.encodePacked(receipient),
            targetAmount - amountInMax
        );

        // if (amountInMax - amounts[0] > 0) {
        //     // Return any change to user
        //     TransferHelper.safeTransfer(targetZRC20, userEvmAddress, amountInMax - amounts[0]);
        // }

        amountsOut = targetAmount - amountInMax;
        
    }

    // Transfer Zeta token to any chain

    function transferZetaToConnectedChain(
        bytes calldata withdrawData,
        address zrc20, // Pass WZETA address here
        address targetZRC20
    ) external payable {
        // Store fee in aZeta
        uint256 platformFeesForTx = (msg.value * platformFee) / 1000; // platformFee = 5 <> 0.5%

        (bool sent, ) = payable(EddyTreasurySafe).call{value: platformFeesForTx}("");

        require(sent, "Failed to transfer aZeta to owner");

        WZETA.deposit{value: msg.value - platformFeesForTx}();

        bool isTargetZRC20BTC_ZETH = targetZRC20 == BTC_ZETH;


        // Hardcoding Zeta price, update when token launched
        // int64 priceUint = prices[AZETA];

        // if (priceUint == 0) revert NoPriceData();

        uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
            UniswapFactory,
            msg.value - platformFeesForTx,
            getPathForTokens(zrc20, targetZRC20)
        );

        uint amountOutMin = (amountsQuote[amountsQuote.length - 1]) - (slippage * amountsQuote[amountsQuote.length - 1]) / 1000;

        uint256 outputAmount = _swap(
            zrc20,
            msg.value - platformFeesForTx,
            targetZRC20,
            amountOutMin
        );
        // gasZRC20CC -> destination chain gas token address in ZetaChain
        (address gasZRC20CC, uint256 gasFeeCC) = IZRC20(targetZRC20)
            .withdrawGasFee();

        

        if (isTargetZRC20BTC_ZETH) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 0);
            (, uint256 gasFee) = IZRC20(targetZRC20).withdrawGasFee();
            IZRC20(targetZRC20).approve(targetZRC20, gasFee);
            if (outputAmount < gasFee) revert WrongAmount();

            IZRC20(targetZRC20).withdraw(recipientAddressBech32, outputAmount - gasFee);

            emit EddyCrossChainSwap(
                zrc20,
                targetZRC20,
                msg.value,
                outputAmount - gasFee,
                msg.sender,
                platformFeesForTx
            );
        } else if (gasZRC20CC != targetZRC20) {
            // Target token is not gas token
            // Swap tokenIn for gasFees
            bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

            uint256 amountsOut = _swapAndSendERC20Tokens(
                targetZRC20,
                gasZRC20CC,
                gasFeeCC,
                recipient,
                outputAmount,
                msg.sender
            );

            emit EddyCrossChainSwap(
                zrc20,
                targetZRC20,
                msg.value,
                amountsOut,
                msg.sender,
                platformFeesForTx
            );

        } else {
            // EVM withdraw
            bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

            SwapHelperLib._doWithdrawal(
                targetZRC20,
                outputAmount,
                recipient
            );

            emit EddyCrossChainSwap(
                zrc20,
                targetZRC20,
                msg.value,
                outputAmount - gasFeeCC,
                msg.sender,
                platformFeesForTx
            );
        }


    }

    function withdrawToNativeChain(
        bytes calldata withdrawData,
        uint256 amount,
        address zrc20,
        address targetZRC20
    ) external {
        address tokenToUse = (targetZRC20 == zrc20) ? zrc20 : targetZRC20;
        // uint256 amountToUse = amount;

        // check for approval
        uint256 allowance = IZRC20(zrc20).allowance(msg.sender, address(this));

        require(allowance > amount, "Not enough allowance of ZRC20 token");

        require(IZRC20(zrc20).transferFrom(msg.sender, address(this), amount), "INSUFFICIENT ALLOWANCE: TRANSFER FROM FAILED");


        uint256 platformFeesForTx = (amount * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(zrc20, EddyTreasurySafe, platformFeesForTx);

        // require(IZRC20(zrc20).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        // Hard coding prices, Would replace when using pyth 
        // (int64 priceUint, int32 expo) = getPriceOfToken(zrc20);

        // if (priceUint == 0) revert NoPriceData();

        (address gasZRC20CC, uint256 gasFeeCC) = IZRC20(targetZRC20)
            .withdrawGasFee();

        if (targetZRC20 != zrc20) {
            console.log("Swapping tokens");
            // swap and update the amount
            uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
                UniswapFactory,
                amount - platformFeesForTx,
                getPathForTokens(zrc20, targetZRC20)
            );

            console.log(amountsQuote[amountsQuote.length - 1], "amountsQuote");

            uint amountOutMin = (amountsQuote[amountsQuote.length - 1]) - (slippage * amountsQuote[amountsQuote.length - 1]) / 1000;

            console.log(amountOutMin, "amountOutMin =====>");

            uint256 amountsOut = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                amountOutMin
            );

            console.log(amountsOut, "amountsOut =====>");

            if (targetZRC20 == BTC_ZETH) {
                bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 0);
                (, uint256 gasFee) = IZRC20(tokenToUse).withdrawGasFee();
                IZRC20(tokenToUse).approve(tokenToUse, gasFee);
                if (amountsOut < gasFee) revert WrongAmount();

                IZRC20(tokenToUse).withdraw(recipientAddressBech32, amountsOut - gasFee);

                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amountsOut - gasFee, msg.sender, platformFeesForTx);
            } else if (gasZRC20CC != targetZRC20) {
                // Target token is not gas token
                // Swap tokenIn for gasFees
                console.log(gasZRC20CC, "gasZRC20CC =====>");

                bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

                uint256 tokenAmountsOut = _swapAndSendERC20Tokens(
                    targetZRC20,
                    gasZRC20CC,
                    gasFeeCC,
                    recipient,
                    amountsOut,
                    msg.sender
                );

                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, tokenAmountsOut, msg.sender, platformFeesForTx);

            } else {
                // EVM withdraw
                bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

                SwapHelperLib._doWithdrawal(
                    tokenToUse,
                    amountsOut,
                    recipient
                );

                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amountsOut - gasFeeCC, msg.sender, platformFeesForTx);
            }

        } else {

            if (targetZRC20 == BTC_ZETH) {
                bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 0);
                (, uint256 gasFee) = IZRC20(tokenToUse).withdrawGasFee();
                IZRC20(tokenToUse).approve(tokenToUse, gasFee);
                if (amount - platformFeesForTx < gasFee) revert WrongAmount();

                IZRC20(tokenToUse).withdraw(recipientAddressBech32, amount - platformFeesForTx - gasFee);
                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amount - platformFeesForTx - gasFee, msg.sender, platformFeesForTx);
            } else if (gasZRC20CC != targetZRC20) {
                // Target token is not gas token
                // Swap tokenIn for gasFees
                bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

                uint256 amountsOut = _swapAndSendERC20Tokens(
                    targetZRC20,
                    gasZRC20CC,
                    gasFeeCC,
                    recipient,
                    amount - platformFeesForTx,
                    msg.sender
                );

                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amountsOut, msg.sender, platformFeesForTx);

            } else {
                // EVM withdraw
                bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

                SwapHelperLib._doWithdrawal(
                    tokenToUse,
                    amount - platformFeesForTx,
                    recipient
                );

                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amount - platformFeesForTx - gasFeeCC, msg.sender, platformFeesForTx);
            }

        }

        
    }

    function _swap(
        address _zrc20,
        uint256 _amount,
        address _targetZRC20,
        uint256 _minAmountOut
    ) internal returns (uint256){

        uint256 outputAmount = SwapHelperLib._doSwap(
            AZETA,
            UniswapFactory,
            UniswapRouter,
            _zrc20,
            _amount,
            _targetZRC20,
            _minAmountOut
        );
        
        return outputAmount;

    }

    receive() external payable {}

    fallback() external payable {}

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
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

    function _existsPairPool(
        address uniswapV2Factory,
        address zrc20A,
        address zrc20B
    ) internal view returns (bool) {
        address uniswapPool = uniswapv2PairFor(
            uniswapV2Factory,
            zrc20A,
            zrc20B
        );
        return
            IZRC20(zrc20A).balanceOf(uniswapPool) > 0 &&
            IZRC20(zrc20B).balanceOf(uniswapPool) > 0;
    }

    function getPathForTokens(
        address zrc20,
        address targetZRC20
    ) internal view returns(address[] memory path) {
        bool existsPairPool = _existsPairPool(
            UniswapFactory,
            zrc20,
            targetZRC20
        );

        if (existsPairPool) {
            path = new address[](2);
            path[0] = zrc20;
            path[1] = targetZRC20;
        } else {
            path = new address[](3);
            path[0] = zrc20;
            path[1] = AZETA;
            path[2] = targetZRC20;
        }
    }

    // Pass min_amount from frontend
    // Integrate pyth > emit in event
    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        if (msg.sender != address(systemContract)) {
            revert SenderNotSystemContract();
        }

        address senderEvmAddress = BytesHelperLib.bytesToAddress(message, 0);

        address targetZRC20 = BytesHelperLib.bytesToAddress(message, 20);

        // Fee for platform
        uint256 platformFeesForTx = (amount * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(zrc20, EddyTreasurySafe, platformFeesForTx);

        // Use safe
        // require(IZRC20(zrc20).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        // int64 priceUint;
        // int32 expo;

        // if (targetZRC20 == AZETA) {
        //     priceUint = prices[AZETA];
        //     expo = 0;
        // } else {
        //     (priceUint, expo) = getPriceOfToken(zrc20);
        // }

        // if (priceUint == 0) revert NoPriceData();


        if (targetZRC20 == zrc20) {
            // same token
            TransferHelper.safeTransfer(targetZRC20, senderEvmAddress, amount - platformFeesForTx);
            // require(IZRC20(targetZRC20).transfer(senderEvmAddress, amount - platformFeesForTx), "Failed to transfer to user wallet");
        } else {

            uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
                UniswapFactory,
                amount - platformFeesForTx,
                getPathForTokens(zrc20, targetZRC20)
            );

            uint amountOutMin = (amountsQuote[amountsQuote.length - 1]) - (slippage * amountsQuote[amountsQuote.length - 1]) / 1000;
            // swap
            uint256 outputAmount = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                amountOutMin
            );

            // Change AZeta address to 0xEeeee...

            if (targetZRC20 == AZETA) {
                // withdraw WZETA to get aZeta in 1:1 ratio
                WZETA.withdraw(outputAmount);
                // transfer azeta
                payable(senderEvmAddress).transfer(outputAmount);
                // (bool sent, ) = payable(senderEvmAddress).call{value: outputAmount}("");
                // require(sent, "Failed to transfer aZeta");
            } else {
                TransferHelper.safeTransfer(targetZRC20, senderEvmAddress, outputAmount);
                // require(IZRC20(targetZRC20).transfer(senderEvmAddress, outputAmount), "Failed to transfer to user wallet");
            }
        }

        emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amount - platformFeesForTx, senderEvmAddress, platformFeesForTx);

    }
}