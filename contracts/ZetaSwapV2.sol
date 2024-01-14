// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";

contract ZetaSwapV2 is zContract, Ownable {
    error SenderNotSystemContract();
    error WrongAmount();
    error NoPriceData();

    SystemContract public immutable systemContract;

    event EddyCrossChainSwap(
        address zrc20,
        address targetZRC20,
        uint256 amount,
        uint256 outputAmount,
        address walletAddress,
        uint256 fees,
        uint256 dollarValueOfTrade
    );

    // Testnet BTC(Zeth)
    address public immutable BTC_ZETH = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
    uint256 public platformFee;
    mapping(address => uint256) public prices;

    constructor(address systemContractAddress, uint256 _platformFee) {
        systemContract = SystemContract(systemContractAddress);
        platformFee = _platformFee;
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

        uint256 platformFeesForTx = (amount * platformFee) / 1000; // platformFee = 5 <> 0.5%

        IZRC20(zrc20).transfer(owner(), platformFeesForTx);

        address targetZRC20 = getTargetOnly(message);
        uint256 minAmt = 0;

        uint256 uintPriceOfAsset = prices[zrc20];

        if (uintPriceOfAsset == 0) revert NoPriceData();

        uint256 dollarValueOfTrade = (amount * uintPriceOfAsset);

         if (targetZRC20 == BTC_ZETH) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(message, 20);
            address evmWalletAddress = BytesHelperLib.bytesToAddress(context.origin, 0);
            uint256 outputAmount = _swap(
                zrc20,
                amount - platformFeesForTx,
                targetZRC20,
                minAmt
            );
            (, uint256 gasFee) = IZRC20(targetZRC20).withdrawGasFee();
            IZRC20(targetZRC20).approve(targetZRC20, gasFee);
            if (outputAmount < gasFee) revert WrongAmount();

            IZRC20(targetZRC20).withdraw(recipientAddressBech32, outputAmount - gasFee);

            emit EddyCrossChainSwap(zrc20, targetZRC20, amount, outputAmount, evmWalletAddress, platformFeesForTx, dollarValueOfTrade);
        } else {
            bytes32 recipient = getRecipientOnly(message);
            address evmWalletAddress = BytesHelperLib.bytesToAddress(message, 20);
            uint256 outputAmount = _swap(
                zrc20,
                amount,
                targetZRC20,
                minAmt
            );

            SwapHelperLib._doWithdrawal(targetZRC20, outputAmount, recipient);
            emit EddyCrossChainSwap(zrc20, targetZRC20, amount, outputAmount, evmWalletAddress, platformFeesForTx, dollarValueOfTrade);
        }
    }
}