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
import "./interfaces/IWZETA.sol";
import "./libraries/UniswapV2Library.sol";

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
        uint256 fees,
        int64 priceUint,
        int32 expo
    );

    SystemContract public immutable systemContract;

    // Testnet BTC(Zeth)
    address public constant BTC_ZETH = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
    address public constant AZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    IWZETA public immutable WZETA;

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

    function transferZetaToConnectedChain(
        bytes calldata withdrawData,
        address zrc20, // Pass WZETA address here
        address targetZRC20
    ) external payable {
        // Store fee in aZeta
        uint256 platformFeesForTx = (msg.value * platformFee) / 1000; // platformFee = 5 <> 0.5%

        (bool sent, ) = payable(owner()).call{value: platformFeesForTx}("");

        require(sent, "Failed to transfer aZeta to owner");

        WZETA.deposit{value: msg.value - platformFeesForTx}();

        bool isTargetZRC20BTC_ZETH = targetZRC20 == BTC_ZETH;


        // Hardcoding Zeta price, update when token launched
        int64 priceUint = prices[AZETA];

        if (priceUint == 0) revert NoPriceData();

        uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
            systemContract.uniswapv2FactoryAddress(),
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

        if (isTargetZRC20BTC_ZETH) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 0);
            (, uint256 gasFee) = IZRC20(targetZRC20).withdrawGasFee();
            IZRC20(targetZRC20).approve(targetZRC20, gasFee);
            if (outputAmount < gasFee) revert WrongAmount();

            IZRC20(targetZRC20).withdraw(recipientAddressBech32, outputAmount - gasFee);
        } else {
            // EVM withdraw
            bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

            SwapHelperLib._doWithdrawal(
                targetZRC20,
                outputAmount,
                recipient
            );
        }

        emit EddyCrossChainSwap(zrc20, targetZRC20, msg.value, msg.value - platformFeesForTx, msg.sender, platformFeesForTx, priceUint, 0);

    }

    function withdrawToNativeChain(
        bytes calldata withdrawData,
        uint256 amount,
        address zrc20,
        address targetZRC20
    ) external {
        bool isTargetZRC20BTC_ZETH = targetZRC20 == BTC_ZETH;
        address tokenToUse = (targetZRC20 == zrc20) ? zrc20 : targetZRC20;
        uint256 amountToUse = amount;

        // check for approval
        uint256 allowance = IZRC20(zrc20).allowance(msg.sender, address(this));

        require(allowance > amount, "Not enough allowance of ZRC20 token");

        require(IZRC20(zrc20).transferFrom(msg.sender, address(this), amount), "INSUFFICIENT ALLOWANCE: TRANSFER FROM FAILED");


        uint256 platformFeesForTx = (amount * platformFee) / 1000; // platformFee = 5 <> 0.5%

        require(IZRC20(zrc20).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        // Hard coding prices, Would replace when using pyth 
        (int64 priceUint, int32 expo) = getPriceOfToken(zrc20);

        if (priceUint == 0) revert NoPriceData();

        if (targetZRC20 != zrc20) {
            // swap and update the amount
            uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
                systemContract.uniswapv2FactoryAddress(),
                amount - platformFeesForTx,
                getPathForTokens(zrc20, targetZRC20)
            );

            uint amountOutMin = (amountsQuote[amountsQuote.length - 1]) - (slippage * amountsQuote[amountsQuote.length - 1]) / 1000;
            
            amountToUse = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                amountOutMin
            );
        }

        if (isTargetZRC20BTC_ZETH) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 0);
            (, uint256 gasFee) = IZRC20(tokenToUse).withdrawGasFee();
            IZRC20(tokenToUse).approve(tokenToUse, gasFee);
            if (amountToUse < gasFee) revert WrongAmount();

            IZRC20(tokenToUse).withdraw(recipientAddressBech32, amountToUse - gasFee);
        } else {
            // EVM withdraw
            bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);

            SwapHelperLib._doWithdrawal(
                tokenToUse,
                amountToUse - platformFeesForTx,
                recipient
            );
        }

        emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amountToUse, msg.sender, platformFeesForTx, priceUint, expo);
    }

    function _swap(
        address _zrc20,
        uint256 _amount,
        address _targetZRC20,
        uint256 _minAmountOut
    ) internal returns (uint256){

        uint256 outputAmount = SwapHelperLib._doSwap(
            systemContract.wZetaContractAddress(),
            systemContract.uniswapv2FactoryAddress(),
            systemContract.uniswapv2Router02Address(),
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
            systemContract.uniswapv2FactoryAddress(),
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

        // Use safe
        require(IZRC20(zrc20).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        int64 priceUint;
        int32 expo;

        if (targetZRC20 == AZETA) {
            priceUint = prices[AZETA];
            expo = 0;
        } else {
            (priceUint, expo) = getPriceOfToken(zrc20);
        }

        if (priceUint == 0) revert NoPriceData();


        if (targetZRC20 == zrc20) {
            // same token
            require(IZRC20(targetZRC20).transfer(senderEvmAddress, amount - platformFeesForTx), "Failed to transfer to user wallet");
        } else {

            uint[] memory amountsQuote = UniswapV2Library.getAmountsOut(
                systemContract.uniswapv2FactoryAddress(),
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
            if (targetZRC20 == AZETA) {
                // withdraw WZETA to get aZeta in 1:1 ratio
                WZETA.withdraw(outputAmount);
                // transfer azeta
                (bool sent, ) = payable(senderEvmAddress).call{value: outputAmount}("");
                require(sent, "Failed to transfer aZeta");
            } else {
                require(IZRC20(targetZRC20).transfer(senderEvmAddress, outputAmount), "Failed to transfer to user wallet");
            }
        }

        emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amount - platformFeesForTx, senderEvmAddress, platformFeesForTx, priceUint, expo);

    }
}