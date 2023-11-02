// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract ZetaSwapV2 is zContract, ZetaInteractor, ZetaReceiver {
    error SenderNotSystemContract();
    error WrongAmount();
    error InvalidMessageType();

    event CrossChainMessageEvent(string);
    event CrossChainMessageRevertedEvent(string);

    SystemContract public immutable systemContract;
    address public constant uniswapV2Router02Addr =
     0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address public constant uniswapV2FactoryAddr = 
     0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c;

    IUniswapV2Router02 public constant uniswapV2Router =
     IUniswapV2Router02(uniswapV2Router02Addr);

    // Map Ethereum address to BTC for withdrawing during remove liquidity
    mapping(address => bytes) public withdrawBTCEVM;
    // Map walletAddress to ZRC20 address & amount
    mapping (address => mapping (address => uint256)) public stakedEvmAmount;
    mapping (bytes => uint256) public stakedBtcAmount;
    mapping (address => uint256) public liquidityMinted;

    // Testnet BTC(Zeth)
    address public immutable BTC_ZETH = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
    // aZeta
    address public immutable ZETA_GAS_TOKEN = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    uint256 constant BITCOIN = 18332;
    uint256 constant BNB = 97;
    uint256 constant GOERLI = 5;
    uint256 constant MUMBAI = 80001;
    uint16 internal constant MAX_DEADLINE = 200;

    ZetaTokenConsumer private immutable _zetaConsumer;
    IERC20 internal immutable _zetaToken;
    bytes32 public constant CROSS_CHAIN_MESSAGE_MESSAGE_TYPE =
        keccak256("CROSS_CHAIN_CROSS_CHAIN_MESSAGE");

    constructor(
        address systemContractAddress,
        address connectorAddress,
        address zetaTokenAddress,
        address zetaConsumerAddress
    ) ZetaInteractor(connectorAddress) {
        systemContract = SystemContract(systemContractAddress);
        _zetaToken = IERC20(zetaTokenAddress);
        _zetaConsumer = ZetaTokenConsumer(zetaConsumerAddress);
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

    function _getTargetRecipientForBTCWithdrawal (bytes calldata message) internal pure returns(bytes memory) {
        return bytesToBech32Bytes(message, 20);
    }

    function _getTargetAndRecipient (
        bytes calldata message
    ) internal pure returns(address targetZRC20BTC, bytes32 recipientBTC) {
        targetZRC20BTC = BytesHelperLib.bytesToAddress(message, 0);
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 20);
        recipientBTC = BytesHelperLib.addressToBytes(recipientAddr);
    }

    function getTargetOnly (bytes calldata message) internal pure returns(address targetChain) {
        return BytesHelperLib.bytesToAddress(message, 0);
    }

    function getRecipientOnly(bytes calldata message) internal pure returns (bytes32 recipientBTC) {
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 20);
        recipientBTC = BytesHelperLib.addressToBytes(recipientAddr);
    }

    function _evmBtcMappingExists (address evmAddress) internal view returns (bool) {
        return withdrawBTCEVM[evmAddress].length > 0;
    }

    function _getTokenPairsInPool (uint256 chainID) internal view returns(address tokenA, address tokenB) {
        // Zeta token in TOKEN/ZETA pool
        tokenB = ZETA_GAS_TOKEN;
        if (chainID == BNB) {
            tokenA = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
        } else if (chainID == BITCOIN) {
            tokenA = 0x65a45c57636f9BcCeD4fe193A602008578BcA90b;
        } else if (chainID == GOERLI) {
            tokenA = 0x13A0c5930C028511Dc02665E7285134B6d11A5f4;
        } else if (chainID == MUMBAI) {
            tokenA = 0x48f80608B672DC30DC7e3dbBd0343c5F02C738Eb;
        }
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

    function sendMessage(
        uint256 destinationChainId,
        bytes destinationAddress,
        bytes message
    ) public payable {
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
                destinationAddress: interactorsByChainId[destinationChainId],
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
        (bytes32 messageType, string memory message) = abi.decode(
            zetaMessage.message,
            (bytes32, string)
        );

        if (messageType != CROSS_CHAIN_MESSAGE_MESSAGE_TYPE)
            revert InvalidMessageType();

        uint256 zetaAmount = zetaMessage.zetaValue;

        (address tokenA, ) = _getTokenPairsInPool(zetaMessage.sourceChainId);

        address senderEvmAddress = BytesHelperLib.bytesToAddress(zetaMessage.zetaTxSenderAddress, 0);

        // Add liquidity
        (, uint amountETH, uint liquidity) = 
            uniswapV2Router.addLiquidityETH{value: zetaAmount}(
                tokenA,
                0,
                0,
                0,
                senderEvmAddress,
                block.timestamp + MAX_DEADLINE
            );

        require(liquidity > 0, "Failed to add liquidity");

        stakedEvmAmount[senderEvmAddress][ZETA_GAS_TOKEN] += amountETH;

        liquidityMinted[senderEvmAddress] += liquidity;


        emit CrossChainMessageEvent(message);
    }

    function onZetaRevert(ZetaInterfaces.ZetaRevert calldata zetaRevert) external override isValidRevertCall(zetaRevert) {
        // Handle the revert
    }

    function removeLiquidityFromPools (
        uint256 liquidityAmount,
        address tokenA,
        address tokenB,
        bytes calldata addressMessage
    ) external {
        // Assume tokenA is native ZRC20
        // Check approval for liquidity token
        address pair = SwapHelperLib.uniswapv2PairFor(uniswapV2FactoryAddr, tokenA, tokenB);
        // Check balance of Liquidity token
        uint256 liquidityBal = IUniswapV2Pair(pair).balanceOf(msg.sender);

        require(liquidityBal > liquidityAmount, "INSUFFICIENT LIQUIDITY TOKEN");

        uint allowance = IUniswapV2Pair(pair).allowance(msg.sender, address(this));

        require(allowance > liquidityAmount, "Approval amount not sufficient for withdraw");

        IUniswapV2Pair(pair).transferFrom(msg.sender, address(this), liquidityAmount);

        // Give approval to uniswap protocol
        IUniswapV2Pair(pair).approve(uniswapV2Router02Addr, liquidityAmount);

        // remove the liquidity and get the pool tokens in the contract
        (uint amountA, uint amountB) = uniswapV2Router.removeLiquidity(
            tokenA,
            tokenB,
            liquidityAmount,
            0,
            0,
            address(this),
            block.timestamp + MAX_DEADLINE
        );

        if (tokenA == BTC_ZETH) {
            // Withdrawing BTC token
            bytes memory btcWithdrawAddress = bytesToBech32Bytes(addressMessage, 0);

            uint256 withdrawableBtcAmount = amountA + outputAmt;

            (, uint256 gasFee) = IZRC20(BTC_ZETH).withdrawGasFee();
            IZRC20(BTC_ZETH).approve(BTC_ZETH, gasFee);
            if (withdrawableBtcAmount < gasFee) revert WrongAmount();

            IZRC20(BTC_ZETH).withdraw(btcWithdrawAddress, withdrawableBtcAmount - gasFee);
        } else {
            // withdraw the tokens
            // Native ZRC20 withdraw
            bytes32 recipientEvm = BytesHelperLib.addressToBytes(msg.sender);
            SwapHelperLib._doWithdrawal(tokenA, amountA, recipientEvm);

            // Withdraw Zeta from Zetachain to connected chain
            
            sendMessage{value: amountB}(

            );
        }

        


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

        (address tokenA, address tokenB) = _getTokenPairsInPool(context.chainID);

        address senderEvmAddress = BytesHelperLib.bytesToAddress(message, 0);

        if (zrc20 == ZETA_GAS_TOKEN) {
            // zeta deposit
            (uint amountToken, uint amountETH, uint liquidity) = uniswapV2Router.addLiquidityETH{value: amount}(
                tokenA,
                0,
                0,
                0,
                senderEvmAddress,
                block.timestamp + MAX_DEADLINE
            );

            require(liquidity > 0, "Failed to add liquidity");

            stakedEvmAmount[senderEvmAddress][ZETA_GAS_TOKEN] += amountETH;

            liquidityMinted[senderEvmAddress] += liquidity;
        } else {
            // ZRC20 deposit
            (uint amountA, uint amountB, uint liquidity) = uniswapV2Router.addLiquidity(
                tokenA,
                tokenB,
                amount,
                0,
                0,
                0,
                senderEvmAddress,
                block.timestamp + MAX_DEADLINE
            );

            require(liquidity > 0, "Failed to add liquidity");

            liquidityMinted[senderEvmAddress] += liquidity;
            stakedEvmAmount[senderEvmAddress][tokenA] += amountA;
        }

    }
}