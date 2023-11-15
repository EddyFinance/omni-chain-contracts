// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";

contract EddyTransferNativeAssets is zContract, Ownable {
    error SenderNotSystemContract();
    error WrongAmount();

    event EddyNativeTokenAssetDeposited(address zrc20, uint256 amount, address user);
    event EddyNativeTokenAssetWithdrawn(address zrc20, uint256 amount, bytes user);

    SystemContract public immutable systemContract;

    // Testnet BTC(Zeth)
    address public immutable BTC_ZETH = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;

    constructor(
        address systemContractAddress
    ) {
        systemContract = SystemContract(systemContractAddress);
    }

    function _getRecipient(bytes calldata message) internal pure returns (bytes32 recipient) {
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 20);
        recipient = BytesHelperLib.addressToBytes(recipientAddr);
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

    function withdrawToNativeChain(
        bytes calldata withdrawData,
        uint256 amount,
        address zrc20
    ) external {
        if (zrc20 == BTC_ZETH) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 20);
            (, uint256 gasFee) = IZRC20(zrc20).withdrawGasFee();
            IZRC20(zrc20).approve(zrc20, gasFee);
            if (amount < gasFee) revert WrongAmount();

            IZRC20(zrc20).withdraw(recipientAddressBech32, amount - gasFee);
        } else {
            // EVM withdraw
            bytes32 recipient = _getRecipient(withdrawData);

            SwapHelperLib._doWithdrawal(
                zrc20,
                amount,
                recipient
            );
        }

        emit EddyNativeTokenAssetWithdrawn(zrc20, amount, withdrawData);
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

        if (targetZRC20 == zrc20) {
            // same token
            IZRC20(targetZRC20).transfer(senderEvmAddress, amount);
        } else {
            // swap
            uint256 outputAmount = _swap(
                    zrc20,
                    amount,
                    targetZRC20,
                    0
            );
            IZRC20(targetZRC20).transfer(senderEvmAddress, outputAmount);
        }

        emit EddyNativeTokenAssetDeposited(senderEvmAddress, amount, senderEvmAddress);

    }
}