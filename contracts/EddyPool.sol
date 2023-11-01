// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract ZetaSwapV2 is zContract {
    error SenderNotSystemContract();
    error WrongAmount();

    SystemContract public immutable systemContract;
    address public constant uniswapV2Router02Addr =
     0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address public constant uniswapV2FactoryAddr = 
     0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c

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

    constructor(address systemContractAddress) {
        systemContract = SystemContract(systemContractAddress);
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

    function _addLiquidityToPools (
        address nativeZRC20Token,
        address zetaToken,
        uint amountADesired,
        address to,
        uint deadline,
        bool zetaDeposit
    ) internal returns (uint amountTokenA, uint amountTokenB, uint liquidityProvided) {

        if (zetaDeposit) {
            // Zeta deposit in TOKEN/ZETA Pool
            (uint amountToken, uint amountETH, uint liquidity) = uniswapV2Router.addLiquidityETH{value: amountADesired}(
                nativeZRC20Token,
                0,
                0,
                0,
                to,
                deadline
            );
            amountTokenA = amountToken;
            amountTokenB = amountETH;
            liquidityProvided = liquidity;

        } else {
            // Token deposit in TOKEN/ZETA Pool
            (uint amountA, uint amountB, uint liquidity) = uniswapV2Router.addLiquidity(
                nativeZRC20Token,
                zetaToken,
                amountADesired,
                0,
                0,
                0,
                to,
                deadline
            );
            amountTokenA = amountA;
            amountTokenB = amountB;
            liquidityProvided = liquidity;
        }
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

    function removeLiquidityFromPools (
        uint256 liquidityAmount,
        address tokenA,
        address tokenB
    ) external {
        // Assume tokenA is native ZRC20
        // Check approval for liquidity token
        address pair = UniswapV2Library.pairFor(uniswapV2FactoryAddr, tokenA, tokenB);
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

        // Convert the ZETA tokens to Native ZRC
        uint256 outputAmt = _swap(
            tokenB,
            amountB,
            tokenA,
            0
        );

        if (tokenA == BTC_ZETH) {
            // Withdrawing BTC token
            bytes memory btcWithdrawAddress = withdrawBTCEVM[msg.sender];

            uint256 withdrawableBtcAmount = amountA + outputAmt;

            (, uint256 gasFee) = IZRC20(BTC_ZETH).withdrawGasFee();
            IZRC20(BTC_ZETH).approve(BTC_ZETH, gasFee);
            if (withdrawableBtcAmount < gasFee) revert WrongAmount();

            IZRC20(BTC_ZETH).withdraw(btcWithdrawAddress, withdrawableBtcAmount - gasFee);
        } else {
            // withdraw the tokens
            // Native ZRC20 withdraw
            SwapHelperLib._doWithdrawal(tokenA, amountA + outputAmt, msg.sender);
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

        if (context.chainID == BITCOIN) {
            // Get the bech32 bitcoin withdrawable address ?? does it come in bytes in case of bitcoin
            bytes memory senderAddress = bytesToBech32Bytes(context.origin, 0);

            address senderEvmAddress = BytesHelperLib.bytesToAddress(message, 0);
            
            // ZRC20 deposit
            (uint amountTokenA, uint amountTokenB, uint liquidityProvided) = _addLiquidityToPools(
                tokenA,
                tokenB,
                amount,
                senderEvmAddress,
                block.timestamp + MAX_DEADLINE,
                false
            );

            require(liquidityProvided > 0, "Failed to add liquidity");

            // Map the BTC deposit to evm address
            if (_evmBtcMappingExists(senderEvmAddress)) {
                // Already staked increase staking amount
                stakedBtcAmount[senderAddress] += amount;
                // Increase liquidity amount
                liquidityMinted[senderEvmAddress] += liquidityProvided;
            } else {
                // Create mapping and increment staking amount
                withdrawBTCEVM[senderEvmAddress] = senderAddress;
                stakedBtcAmount[senderAddress] += amount;
                liquidityMinted[senderEvmAddress] += liquidityProvided;
            }
            
        } else {
            address senderAddress = BytesHelperLib.bytesToAddress(context.origin, 0);
            if (zrc20 == ZETA_GAS_TOKEN) {
                // zeta deposit
                (uint amountTokenA, uint amountTokenB, uint liquidityProvided) = _addLiquidityToPools(
                    tokenA,
                    tokenB,
                    amount,
                    senderAddress,
                    block.timestamp + MAX_DEADLINE,
                    true
                );

                require(liquidityProvided > 0, "Failed to add liquidity");

                stakedEvmAmount[senderAddress][ZETA_GAS_TOKEN] += amount;

                liquidityMinted[senderAddress] += liquidityProvided;

            } else {
                // ZRC20 deposit
                (uint amountTokenA, uint amountTokenB, uint liquidityProvided) = _addLiquidityToPools(
                    tokenA,
                    tokenB,
                    amount,
                    senderAddress,
                    block.timestamp + MAX_DEADLINE,
                    false
                );
                require(liquidityProvided > 0, "Failed to add liquidity");

                stakedEvmAmount[senderAddress][zrc20] += amount;
                liquidityMinted[senderAddress] += liquidityProvided;

            }

        }

    }
}