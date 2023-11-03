// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IWZETA.sol";
import "./interfaces/IEddyPool.sol";

contract EddyEvmConnector is ZetaInteractor, ZetaReceiver {

    error InvalidMessageType();

    event CrossChainMessageEvent(address);
    event CrossChainMessageRevertedEvent(string);

    ZetaTokenConsumer private immutable _zetaConsumer;
    IERC20 internal immutable _zetaToken;
    bytes32 public constant CROSS_CHAIN_MESSAGE_MESSAGE_TYPE =
        keccak256("CROSS_CHAIN_CROSS_CHAIN_MESSAGE");

    
    constructor(
        address connectorAddress,
        address zetaTokenAddress,
        address zetaConsumerAddress
    ) ZetaInteractor(connectorAddress) {
        _zetaToken = IERC20(zetaTokenAddress);
        _zetaConsumer = ZetaTokenConsumer(zetaConsumerAddress);
    }

    function sendMessage(
        uint256 destinationChainId,
        bytes calldata destinationAddress, //TODO: EddyConnector in Zetachain
        bytes calldata message
    ) external payable {
        if (!_isValidChainId(destinationChainId))
            revert InvalidDestinationChainId();
        uint256 crossChainGas = 2 * (10 ** 18);
        uint256 zetaValueAndGas = _zetaConsumer.getZetaFromEth{
            value: msg.value
        }(address(this), crossChainGas);

        _zetaToken.approve(address(connector), zetaValueAndGas);

        connector.send(
            ZetaInterfaces.SendInput({
                destinationChainId: destinationChainId,
                destinationAddress: destinationAddress,
                destinationGasLimit: 300000,
                message: abi.encode(CROSS_CHAIN_MESSAGE_MESSAGE_TYPE, message),
                zetaValueAndGas: zetaValueAndGas,
                zetaParams: abi.encode("")
            })
        );
    }

    function onZetaMessage(
        ZetaInterfaces.ZetaMessage calldata zetaMessage
    ) external override isValidMessageCall(zetaMessage) {
        (bytes32 messageType, address message) = abi.decode(
            zetaMessage.message,
            (bytes32, address)
        );

        if (messageType != CROSS_CHAIN_MESSAGE_MESSAGE_TYPE)
            revert InvalidMessageType();

        uint256 zetaAmount = zetaMessage.zetaValue;

        // send the user zeta
        address userAddress = message;

        _zetaToken.transferFrom(address(this), userAddress, zetaAmount);

        emit CrossChainMessageEvent(message);
    }

    function onZetaRevert(
        ZetaInterfaces.ZetaRevert calldata zetaRevert
    ) external override isValidRevertCall(zetaRevert) {
        (bytes32 messageType, string memory message) = abi.decode(
            zetaRevert.message,
            (bytes32, string)
        );

        if (messageType != CROSS_CHAIN_MESSAGE_MESSAGE_TYPE)
            revert InvalidMessageType();

        emit CrossChainMessageRevertedEvent(message);
    }

}