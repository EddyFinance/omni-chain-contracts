// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
import "./interfaces/IWZETA.sol";
import "./interfaces/IEddyPool.sol";

contract EddyConnector is ZetaInteractor, ZetaReceiver {

    error InvalidMessageType();

    event CrossChainMessageEvent(address);
    event CrossChainMessageRevertedEvent(address);

    IWZETA internal immutable _zetaToken;
    IEddyPool public _eddyPool;
    bytes32 public constant CROSS_CHAIN_MESSAGE_MESSAGE_TYPE =
        keccak256("CROSS_CHAIN_CROSS_CHAIN_MESSAGE");

    
    constructor(
        address connectorAddress,
        address zetaTokenAddress
    ) ZetaInteractor(connectorAddress) {
        _zetaToken = IWZETA(zetaTokenAddress);
    }

    function setPoolContract(address eddyPoolContract) external onlyOwner {
        _eddyPool = IEddyPool(eddyPoolContract);
    }

    function sendMessage(
        uint256 destinationChainId,
        bytes calldata destinationAddress,
        bytes calldata message
    ) external payable {
        if (!_isValidChainId(destinationChainId))
            revert InvalidDestinationChainId();

        require(msg.value > 2 * (10**18), "ZETA AMOUNT INSUFFICIENT FOR GAS FEES");

        // Convert native Zeta to WZeta
        
        _zetaToken.deposit{value: msg.value}();

        _zetaToken.approve(address(connector), msg.value);

        connector.send(
            ZetaInterfaces.SendInput({
                destinationChainId: destinationChainId,
                destinationAddress: destinationAddress,
                destinationGasLimit: 300000,
                message: abi.encode(CROSS_CHAIN_MESSAGE_MESSAGE_TYPE, message),
                zetaValueAndGas: msg.value,
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
        // WZETA 
        uint256 zetaAmount = zetaMessage.zetaValue;

        // Convert WZETA to Native Zeta
        _zetaToken.withdraw(zetaAmount);
        address userAddress = message;

        _eddyPool.addZetaLiquidityToPools{value: zetaAmount}(
            userAddress,
            zetaMessage.sourceChainId
        );

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

        // return the zeta to the user on zetachain. User can withdraw later
        address userAddress = message;

        _zetaToken.transfer(userAddress, zetaRevert.remainingZetaValue);

        emit CrossChainMessageRevertedEvent(message);
    }

}