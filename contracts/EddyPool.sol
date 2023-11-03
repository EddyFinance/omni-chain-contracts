// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWZETA.sol";
import "./interfaces/IEddyConnector.sol";

contract ZetaSwapV2 is zContract {
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

    // Map walletAddress to ZRC20 address & amount
    mapping (address => mapping (address => uint256)) public stakedAmount;
    // mapping (bytes => uint256) public stakedBtcAmount;
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

    IWZETA internal immutable _zetaToken;
    IEddyConnector internal immutable _eddyConnector;

    constructor(
        address systemContractAddress,
        address zetaTokenAddress,
        address eddyConnector
    ) {
        systemContract = SystemContract(systemContractAddress);
        _zetaToken = IWZETA(zetaTokenAddress);
        _eddyConnector = IEddyConnector(eddyConnector);
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

    function addZetaLiquidityToPools (
        bytes calldata senderAddress,
        uint256 sourceChainId
    ) external payable {
        uint256 zetaAmount = msg.value;

        (address tokenA, ) = _getTokenPairsInPool(sourceChainId);

        address senderEvmAddress = BytesHelperLib.bytesToAddress(senderAddress, 0);

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

        stakedAmount[senderEvmAddress][ZETA_GAS_TOKEN] += amountETH;

        liquidityMinted[senderEvmAddress] += liquidity;
    }

    function removeLiquidityFromPools (
        uint256 liquidityAmount,
        address tokenA,
        address tokenB,
        uint256 destinationChainId,
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

            uint256 withdrawableBtcAmount = amountA;

            (, uint256 gasFee) = IZRC20(BTC_ZETH).withdrawGasFee();
            IZRC20(BTC_ZETH).approve(BTC_ZETH, gasFee);
            if (withdrawableBtcAmount < gasFee) revert WrongAmount();

            IZRC20(BTC_ZETH).withdraw(btcWithdrawAddress, withdrawableBtcAmount - gasFee);

            // Withdraw zeta to zetachain
            IWZETA(tokenB).transfer(msg.sender, amountB);

            liquidityMinted[msg.sender] -= liquidityAmount;
            stakedAmount[msg.sender][BTC_ZETH] -= amountA;
            stakedAmount[msg.sender][ZETA_GAS_TOKEN] -= amountB;
        } else {
            // withdraw the tokens
            // Native ZRC20 withdraw
            bytes32 recipientEvm = BytesHelperLib.addressToBytes(msg.sender);
            SwapHelperLib._doWithdrawal(tokenA, amountA, recipientEvm);

            // Withdraw Zeta from Zetachain to connected chain
            _eddyConnector.sendMessage{value: amountB}(
                destinationChainId,
                abi.encodePacked(msg.sender),
                bytes("")
            );

            liquidityMinted[msg.sender] -= liquidityAmount;
            stakedAmount[msg.sender][BTC_ZETH] -= amountA;
            stakedAmount[msg.sender][ZETA_GAS_TOKEN] -= amountB;

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
        stakedAmount[senderEvmAddress][tokenA] += amountA;

    }
}