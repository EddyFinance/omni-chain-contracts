// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/contracts/interfaces/hooks/IPostDispatchHook.sol";
import {IMessageRecipient} from "@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol";
import {IInterchainSecurityModule, ISpecifiesInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/TransferHelper.sol";

contract EddyCrossChainMailBox is Ownable, IMessageRecipient {
    // Hyperlane Mailbox contract to listen to
    IMailbox public mailbox;
    // Hyperlane post dispatch hook. Should be MerkleTreeHook contract instance
    IPostDispatchHook public hook;
    address ADMIN = 0x06Cf18ec8DaDA3E6b86c38DE2c5536811Cd9594C;
    address private constant EddyTreasurySafe =
        0x3f641963f3D9ADf82D890fd8142313dCec807ba5;
    mapping(uint32 => address) private counterChainContracts;
    mapping(uint32 => bool) private chainExists;
    uint256 public platformFee;

    // event ReceivedCounterValue(uint256 receivedValue);
    event MessageSent(bytes32 messageId);

    modifier onlyMailbox() {
        require(
            msg.sender == address(mailbox),
            "This function can be called only by Mailbox"
        );
        _;
    }

    constructor(IMailbox _mailbox, uint256 _platformFee) {
        mailbox = _mailbox;
        platformFee = _platformFee;
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external payable override {
        // Check if message was delivered from expected chain

        require(chainExists[_origin], "MESSAGE_DELIVERED_FROM_UNKNOWN_CHAIN");

        // Check if message was sent by our contract in other chain
        address decodedSender = address(uint160(uint256(_sender)));
        require(
            decodedSender == counterChainContracts[_origin],
            "Cross-chain transaction should be initiated by CrossChainCounter"
        );

        // Decode message body and emit event
        (address recipient, uint256 amount) = abi.decode(
            _message,
            (address, uint256)
        );

        uint256 platformFeesForTx = (amount * platformFee) / 1000; // platformFee = 5 <> 0.5%
        {
            (bool sent, ) = payable(EddyTreasurySafe).call{
                value: platformFeesForTx
            }("");
            require(sent, "Failed to send Ether to Eddy treasury");

            (bool sentToUser, ) = payable(recipient).call{
                value: amount - platformFeesForTx
            }("");
            require(sentToUser, "Failed to send Ether to User");
        }
    }

    function sendCrossChainMessage(
        address recipientAddress,
        uint32 _chainId
    ) public payable {
        // At least 1 wei should be sent within transaction to cover transaction fees
        require(msg.value > 0, "ZERO_AMOUNT_TRANSACTION");
        //Check if chain is supported yet.
        require(chainExists[_chainId], "CHAIN NOT SUPPORTED");

        // Encode recipient address
        bytes32 encodedAddress = bytes32(
            uint256(uint160(counterChainContracts[_chainId]))
        );

        // Encode message data conatiaing user address and transaction amount.
        //Calculate hyperlane platform fee and check it with amount passed.
        uint256 fee = mailbox.quoteDispatch(
            _chainId,
            encodedAddress,
            abi.encode(recipientAddress, msg.value)
        );

        require(msg.value > fee, "INSUFFICIENT_AMOUNT_TO_COVER_FEES");
        require(
            msg.value - fee < address(counterChainContracts[_chainId]).balance,
            "INSUFFICIENT_LIQUIDITY_FOR_TRANSACTION"
        );

        // Call `dispatch` function at Mailbox contract to broadcast message
        bytes32 messageId = mailbox.dispatch{value: fee}(
            _chainId,
            encodedAddress,
            abi.encode(recipientAddress, msg.value - fee)
        );

        // Emit event with message id
        emit MessageSent(messageId);
    }

    function getGasQuoteforCrossChain(
        uint32 _chainId,
        uint256 amount,
        address recipientAddress
    ) external view returns (uint256) {
        require(chainExists[_chainId], "CHAIN NOT SUPPORTED");
        bytes32 encodedAddress = bytes32(
            uint256(uint160(counterChainContracts[_chainId]))
        );
        uint256 fee = mailbox.quoteDispatch(
            _chainId,
            encodedAddress,
            abi.encode(recipientAddress, amount)
        );
        return fee;
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function recoverSigner(
        bytes32 message,
        bytes memory sig
    ) internal pure returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (uint8, bytes32, bytes32) {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function withdrawBalance() public onlyOwner {
        (bool sentToUser, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(sentToUser, "Failed to send Ether to User");
    }

    function setCounterChainContracts(
        uint32[] memory _chainIds,
        address[] memory _counterChainaddresses
    ) public onlyOwner {
        require(
            _chainIds.length == _counterChainaddresses.length,
            "Keys and values array length must match"
        );
        for (uint256 i = 0; i < _chainIds.length; i++) {
            counterChainContracts[_chainIds[i]] = _counterChainaddresses[i];
            chainExists[_chainIds[i]] = true;
        }
    }

    function changeCounterChainContracts(
        uint32 _chainId,
        address _counterChainContract
    ) public onlyOwner {
        require(chainExists[_chainId], "CHAIN_IS_NOT_SUPPORTED");
        counterChainContracts[_chainId] = _counterChainContract;
    }

    function getCounterChainContracts(
        uint32 _chainId
    ) public view onlyOwner returns (address) {
        require(chainExists[_chainId], "CHAIN_IS_NOT_SUPPORTED");
        return counterChainContracts[_chainId];
    }

    receive() external payable {}

    fallback() external payable {}
}
