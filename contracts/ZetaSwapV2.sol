// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";

contract ZetaSwapV2 is zContract {
    SystemContract public immutable systemContract;

    constructor(address systemContractAddress) {
        systemContract = SystemContract(systemContractAddress);
    }

    function _getTargetAndRecipient (
        bytes calldata message
    ) internal pure returns(address targetZRC20BTC, bytes32 recipientBTC) {
        targetZRC20BTC = BytesHelperLib.bytesToAddress(message, 0);
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 20);
        recipientBTC = BytesHelperLib.addressToBytes(recipientAddr);
    }

    function _swapAndWithdraw(
        address _zrc20,
        uint256 _amount,
        address _targetZRC20,
        uint256 _minAmountOut,
        bytes32 _recipient
    ) internal {

        uint256 outputAmount = SwapHelperLib._doSwap(
            systemContract.wZetaContractAddress(),
            systemContract.uniswapv2FactoryAddress(),
            systemContract.uniswapv2Router02Address(),
            _zrc20,
            _amount,
            _targetZRC20,
            _minAmountOut
        );
        SwapHelperLib._doWithdrawal(_targetZRC20, outputAmount, _recipient);

    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        (address targetZRC20, bytes32 recipient) = _getTargetAndRecipient(message);
            uint256 minAmt = 0;
            _swapAndWithdraw(
                zrc20,
                amount,
                targetZRC20,
                minAmt,
                recipient
            );
    }
}