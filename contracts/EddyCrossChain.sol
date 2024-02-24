// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/TransferHelper.sol";

contract EddyCrossChain is zContract, Ownable {
    error SenderNotSystemContract();
    error WrongAmount();
    error NoPriceData();
    error IdenticalAddresses();
    error ZeroAddress();

    SystemContract public immutable systemContract;

    IPyth pyth;

    event EddyCrossChainSwap(
        address zrc20,
        address targetZRC20,
        uint256 amount,
        uint256 outputAmount,
        address walletAddress,
        uint256 fees
    );

    // Testnet BTC(Zeth)
    address public constant BTC_ZETH = 0x13A0c5930C028511Dc02665E7285134B6d11A5f4;
    address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    address public constant UniswapRouter = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address public constant UniswapFactory = 0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c;
    uint16 internal constant MAX_DEADLINE = 200;

    address private constant EddyTreasurySafe = 0x3f641963f3D9ADf82D890fd8142313dCec807ba5;

    uint256 public platformFee;
    uint256 public slippage;

    mapping(address => int64) public prices;

    mapping(address => bytes32) public addressToTokenId;

    constructor(
        address systemContractAddress,
        address _pythContractAddress,
        uint256 _platformFee,
        uint256 _slippage
    ) {
        systemContract = SystemContract(systemContractAddress);
        pyth = IPyth(_pythContractAddress);
        platformFee = _platformFee;
        slippage = _slippage;
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

    function _getTargetRecipientForBTCWithdrawal (bytes calldata message) internal pure returns(bytes memory) {
        return bytesToBech32Bytes(message, 20);
    }

    function _getTargetAndRecipient (
        bytes calldata message
    ) internal pure returns(address targetZRC20BTC, bytes32 recipientBTC) {
        targetZRC20BTC = BytesHelperLib.bytesToAddress(message, 0);
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 20);
        recipientBTC = BytesHelperLib.addressToBytes(recipientAddr);
    }

    function getTargetOnly (bytes calldata message) internal pure returns(address targetChain) {
        return BytesHelperLib.bytesToAddress(message, 0);
    }

    function getRecipientOnly(bytes calldata message) internal pure returns (bytes32 recipientBTC) {
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 20);
        recipientBTC = BytesHelperLib.addressToBytes(recipientAddr);
    }

    function _swap(
        address _zrc20,
        uint256 _amount,
        address _targetZRC20,
        uint256 _minAmountOut
    ) internal returns (uint256){

        uint256 outputAmount = SwapHelperLib._doSwap(
            WZETA,
            UniswapFactory,
            UniswapRouter,
            _zrc20,
            _amount,
            _targetZRC20,
            _minAmountOut
        );
        
        return outputAmount;

    }

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
            path[1] = WZETA;
            path[2] = targetZRC20;
        }
    }

    receive() external payable {}

    fallback() external payable {}

    function _swapAndSendERC20Tokens(
        address targetZRC20,
        address gasZRC20,
        uint256 gasFee,
        bytes32 receipient,
        uint256 targetAmount,
        address userEvmAddress
    ) internal returns(uint256 amountsOutTarget) {

        // Get amountOut for Input gasToken
        uint[] memory amountsQuote = UniswapV2Library.getAmountsIn(
            UniswapFactory,
            gasFee,
            getPathForTokens(targetZRC20, gasZRC20)
        );

        uint amountInMax = (amountsQuote[0]) + (slippage * amountsQuote[0]) / 1000;

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

        require(IZRC20(gasZRC20).balanceOf(address(this)) >= gasFee, "INSUFFICIENT_GAS_FOR_WITHDRAW");

        IZRC20(gasZRC20).approve(targetZRC20, gasFee);

        require(targetAmount - amountInMax > 0, "INSUFFICIENT_AMOUNT_FOR_WITHDRAW");

        IZRC20(targetZRC20).withdraw(
            abi.encodePacked(receipient),
            targetAmount - amountInMax
        );

        // if (amountInMax - amounts[0] > 0) {
        //     // Return any change to user
        //     TransferHelper.safeTransfer(targetZRC20, userEvmAddress, amountInMax - amounts[0]);

        // }

        amountsOutTarget = targetAmount - amountInMax;
        
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        if (msg.sender != address(systemContract)) {
            revert SenderNotSystemContract();
        }

        uint256 platformFeesForTx = (amount * platformFee) / 1000; // platformFee = 5 <> 0.5%

        TransferHelper.safeTransfer(zrc20, EddyTreasurySafe, platformFeesForTx);

        // require(IZRC20(zrc20).transfer(owner(), platformFeesForTx), "ZRC20 - Transfer failed to owner");

        // First 20 bytes is target
        address targetZRC20 = getTargetOnly(message);

        uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
            UniswapFactory,
            amount - platformFeesForTx,
            getPathForTokens(zrc20, targetZRC20)
        );

        uint amountOutMin = (amountsQuote[amountsQuote.length - 1]) - (slippage * amountsQuote[amountsQuote.length - 1]) / 1000;

        // (int64 priceUint, int32 expo) = getPriceOfToken(zrc20);

        // if (priceUint == 0) revert NoPriceData();

        (address gasZRC20, uint256 gasFee) = IZRC20(targetZRC20)
            .withdrawGasFee();

         if (targetZRC20 == BTC_ZETH) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(message, 20);
            address evmWalletAddress = BytesHelperLib.bytesToAddress(context.origin, 0);
            uint256 outputAmount = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                amountOutMin
            );
            (, uint256 gasFee) = IZRC20(targetZRC20).withdrawGasFee();
            IZRC20(targetZRC20).approve(targetZRC20, gasFee);
            if (outputAmount < gasFee) revert WrongAmount();

            IZRC20(targetZRC20).withdraw(recipientAddressBech32, outputAmount - gasFee);

            emit EddyCrossChainSwap(zrc20, targetZRC20, amount, outputAmount, evmWalletAddress, platformFeesForTx);
        } else {
            bytes32 recipient = getRecipientOnly(message);
            address evmWalletAddress = BytesHelperLib.bytesToAddress(message, 20);
            uint256 outputAmount = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                amountOutMin
            );

            if (gasZRC20 != targetZRC20) {
                // target token not gas token
                // withdraw token not gas token
                uint256 amountsOutTarget = _swapAndSendERC20Tokens(
                    targetZRC20,
                    gasZRC20,
                    gasFee,
                    recipient,
                    outputAmount,
                    evmWalletAddress
                );
                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amountsOutTarget, evmWalletAddress, platformFeesForTx);
            } else {
                SwapHelperLib._doWithdrawal(targetZRC20, outputAmount, recipient);
                emit EddyCrossChainSwap(zrc20, targetZRC20, amount, outputAmount, evmWalletAddress, platformFeesForTx);
            }

        }
    }
}