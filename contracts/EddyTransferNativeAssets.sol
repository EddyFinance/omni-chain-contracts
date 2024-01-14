// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "./interfaces/IWZETA.sol";

contract EddyTransferNativeAssets is zContract, Ownable {
    error SenderNotSystemContract();
    error WrongAmount();
    error NoPriceData();

    event EddyCrossChainSwap(
        address zrc20,
        address targetZRC20,
        uint256 amount,
        uint256 outputAmount,
        address walletAddress,
        uint256 fees,
        uint256 dollarValueOfTrade
    );

    SystemContract public immutable systemContract;

    // Testnet BTC(Zeth)
    address public immutable BTC_ZETH = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
    address public immutable AZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    IWZETA public immutable WZETA;
    uint256 public platformFee;
    mapping(address => uint256) public prices;

    constructor(
        address systemContractAddress,
        address wrappedZetaToken,
        uint256 _platformFee
    ) {
        systemContract = SystemContract(systemContractAddress);
        WZETA = IWZETA(wrappedZetaToken);
        platformFee = _platformFee;
    }

    function _getRecipient(bytes calldata message) internal pure returns (bytes32 recipient) {
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 0);
        recipient = BytesHelperLib.addressToBytes(recipientAddr);
    }

    function updatePriceForAsset(address asset, uint256 price) external onlyOwner {
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

    function withdrawFromZetaToConnectedChain(
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

        uint256 uintPriceOfAsset = prices[targetZRC20];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (msg.value * uintPriceOfAsset);

        uint256 outputAmount = _swap(
            zrc20,
            msg.value - platformFeesForTx,
            targetZRC20,
            0
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

        emit EddyCrossChainSwap(zrc20, targetZRC20, msg.value, msg.value - platformFeesForTx, msg.sender, platformFeesForTx, dollarValueOfTrade);

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

        require(IZRC20(targetZRC20).transfer(owner(), platformFeesForTx), "Failed to transfer to owner()");

        // Hard coding prices, Would replace when using pyth 
        uint256 uintPriceOfAsset = prices[zrc20];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amount * uintPriceOfAsset);

        if (targetZRC20 != zrc20) {
            // swap and update the amount
            amountToUse = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                0
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
                amountToUse,
                recipient
            );
        }

        emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amountToUse, msg.sender, platformFeesForTx, dollarValueOfTrade);
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

        // Hard coding prices, Would replace when using pyth
        uint256 uintPriceOfAsset = prices[zrc20];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amount * uintPriceOfAsset);


        if (targetZRC20 == zrc20) {
            // same token
            require(IZRC20(targetZRC20).transfer(senderEvmAddress, amount - platformFeesForTx), "Failed to transfer to user wallet");
        } else {
            // swap
            uint256 outputAmount = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                0
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

        emit EddyCrossChainSwap(zrc20, targetZRC20, amount, amount - platformFeesForTx, senderEvmAddress, platformFeesForTx, dollarValueOfTrade);

    }
}