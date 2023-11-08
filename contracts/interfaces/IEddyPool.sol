interface IEddyPool {
    function addZetaLiquidityToPools (
        address senderEvmAddress,
        uint256 sourceChainId
    ) external payable;
}