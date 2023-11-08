// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
import "./interfaces/IWZETA.sol";
import "./interfaces/IEddyPool.sol";

contract EddyConnector is ZetaInteractor, ZetaReceiver {

    error InvalidMessageType();

    event CrossChainMessageEvent(string);
    event CrossChainMessageRevertedEvent(string);

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

    function bytesToAddress(
        bytes calldata data,
        uint256 offset
    ) internal pure returns (address output) {
        bytes memory b = data[offset:offset + 20];
        assembly {
            output := mload(add(b, 20))
        }
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
        (bytes32 messageType, string memory message) = abi.decode(
            zetaMessage.message,
            (bytes32, string)
        );

        if (messageType != CROSS_CHAIN_MESSAGE_MESSAGE_TYPE)
            revert InvalidMessageType();
        // WZETA 
        uint256 zetaAmount = zetaMessage.zetaValue;
        address recipientAddress = bytesToAddress(zetaMessage.zetaTxSenderAddress, 0);
        address payable senderEvmAddress = payable(recipientAddress);

        // Convert WZETA to Native Zeta
        _zetaToken.withdraw(zetaAmount);

        // Send zeta to user
        bool sent = senderEvmAddress.send(zetaAmount);

        require(sent, "Failed to transfer Native zeta to user");

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

        // return the zeta to the user on zetachain. User can withdraw later
        address senderEvmAddress = zetaRevert.zetaTxSenderAddress;

        _zetaToken.transfer(senderEvmAddress, zetaRevert.remainingZetaValue);

        emit CrossChainMessageRevertedEvent(message);
    }

}