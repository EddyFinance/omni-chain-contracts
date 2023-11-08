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
    event CrossChainMessageRevertedEvent(address);

    IERC20 internal immutable _zetaToken;
    bytes32 public constant CROSS_CHAIN_MESSAGE_MESSAGE_TYPE =
        keccak256("CROSS_CHAIN_CROSS_CHAIN_MESSAGE");

    
    constructor(
        address connectorAddress,
        address zetaTokenAddress
    ) ZetaInteractor(connectorAddress) {
        _zetaToken = IERC20(zetaTokenAddress);
    }

    function sendMessage(
        uint256 destinationChainId,
        bytes calldata destinationAddress, //TODO: EddyConnector in Zetachain
        bytes calldata message,
        uint zetaAmountForTransfer
    ) external {
        if (!_isValidChainId(destinationChainId))
            revert InvalidDestinationChainId();
        // Check approval for Zeta token
        require(zetaAmountForTransfer > 2 * (10**18), "INSUFFICIENT AMOUNT FOR GAS");
        uint256 allowance = _zetaToken.allowance(msg.sender, address(this));

        require(allowance > zetaAmountForTransfer, "INSUFFICIENT ALLOWANCE FOR TOKEN");

        // Transfer the WZeta token from user to our contract

        _zetaToken.transferFrom(msg.sender, address(this), zetaAmountForTransfer);

        _zetaToken.approve(address(connector), zetaAmountForTransfer);

        connector.send(
            ZetaInterfaces.SendInput({
                destinationChainId: destinationChainId,
                destinationAddress: destinationAddress,
                destinationGasLimit: 300000,
                message: abi.encode(CROSS_CHAIN_MESSAGE_MESSAGE_TYPE, message),
                zetaValueAndGas: zetaAmountForTransfer,
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
        (bytes32 messageType, address message) = abi.decode(
            zetaRevert.message,
            (bytes32, address)
        );

        if (messageType != CROSS_CHAIN_MESSAGE_MESSAGE_TYPE)
            revert InvalidMessageType();

        uint256 remainingZeta = zetaRevert.remainingZetaValue;

        // send the user zeta
        address userAddress = message;

        _zetaToken.transfer(userAddress, remainingZeta);


        emit CrossChainMessageRevertedEvent(userAddress);
    }

}