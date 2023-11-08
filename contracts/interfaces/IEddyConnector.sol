interface IEddyConnector {
    function sendMessage(
        uint256 destinationChainId,
        bytes calldata destinationAddress,
        bytes calldata message
    ) external payable;
}