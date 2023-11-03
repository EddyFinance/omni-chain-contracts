interface IEddyPool {
    function addZetaLiquidityToPools (
        bytes calldata senderAddress,
        uint256 sourceChainId
    ) external payable;
}