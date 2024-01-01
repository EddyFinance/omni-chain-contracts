// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// ███████╗██████╗░██████╗░██╗░░░██╗  ███████╗██╗███╗░░██╗░█████╗░███╗░░██╗░█████╗░███████╗
// ██╔════╝██╔══██╗██╔══██╗╚██╗░██╔╝  ██╔════╝██║████╗░██║██╔══██╗████╗░██║██╔══██╗██╔════╝
// █████╗░░██║░░██║██║░░██║░╚████╔╝░  █████╗░░██║██╔██╗██║███████║██╔██╗██║██║░░╚═╝█████╗░░
// ██╔══╝░░██║░░██║██║░░██║░░╚██╔╝░░  ██╔══╝░░██║██║╚████║██╔══██║██║╚████║██║░░██╗██╔══╝░░
// ███████╗██████╔╝██████╔╝░░░██║░░░  ██║░░░░░██║██║░╚███║██║░░██║██║░╚███║╚█████╔╝███████╗
// ╚══════╝╚═════╝░╚═════╝░░░░╚═╝░░░  ╚═╝░░░░░╚═╝╚═╝░░╚══╝╚═╝░░╚═╝╚═╝░░╚══╝░╚════╝░╚══════╝

// zeta dependencies
import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import  "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import  "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {IZRC20Metadata} from  "@zetachain/protocol-contracts/contracts/zevm/Interfaces.sol";

// pyth dependencies
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

// oz dependencies
import "@openzeppelin/contracts/access/Ownable.sol";

contract EddyTransferNativeAssets is zContract, Ownable {

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    
    /// @dev Contract call made is not from Zeta's TSS address
    error SenderNotSystemContract(address falseCaller);

    /// @dev Not enough final amount (less gas fees) to withdraw to native chain
    error WrongAmount();

    /// @dev Input array's length not same
    error InvalidInput();

    /// @dev Invalid Price 
    error InvalidPrice();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev 
    event EddyNativeTokenAssetDeposited(address indexed zrc20, uint256 indexed amount, address indexed user);

    /// @dev 
    event EddyNativeTokenAssetWithdrawn(address indexed zrc20, uint256 indexed amount, bytes indexed user);

    /// @dev 
    event EddyRewards(address indexed zrc20, uint256 indexed currentPrice, address indexed user);

    /// @dev
    event FeeChanged(uint256 indexed oldBP, uint256 indexed newBP);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev feePercentage is represented in basis points [ 1% == 100 bp ]
    uint256 public feeCharge;
    
    /// @dev Instance of SystemContract used for calling Zeta's TSS Address
    SystemContract public immutable systemContract;

    /// @dev Instance of Pyth Oracle Data Provider
    IPyth public immutable pythNetwork;

    /// @dev 
    address public immutable BTC_ZRC20; //0x65a45c57636f9BcCeD4fe193A602008578BcA90b;

    /// @dev 
    mapping(address=>bytes32) addressToPriceFeed;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(
        address _systemContractAddress,
        address _BTC_ZRC20,
        address _pythNetwork,
        uint256 _feeCharge
    ) Ownable() {
        systemContract = SystemContract(_systemContractAddress);
        pythNetwork = IPyth(_pythNetwork);
        BTC_ZRC20 = _BTC_ZRC20;
        feeCharge = _feeCharge;
        emit FeeChanged(0, _feeCharge);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ADMIN                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function initializePriceFeedId(address[] memory _zrcAddresses, bytes32[] memory _priceIds) external onlyOwner {
        if( _zrcAddresses.length != _priceIds.length ){
            revert InvalidInput();
        }
        uint256 len = _zrcAddresses.length;
        for ( uint256 i; i<len;){
            addressToPriceFeed[_zrcAddresses[i]] = _priceIds[i];
            unchecked {
                ++i;
            }
        }
    }

    /// trying something new here, emitting before state changes. 
    /// idk why this would fail : ask 
    function setFeeCharge(uint256 _newFeeCharge) external onlyOwner {
        emit FeeChanged(feeCharge,_newFeeCharge);
        feeCharge = _newFeeCharge;     
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CORE FUNCTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Every SystemContract call to this function
    /// @notice comes with an associated ZRC20 amount ( zeta does this via core ZETA Pools )
    /// @param message : Customizable by the protocol, we embed senderEVMAddress and the zrc20 token to swap with 

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        if (msg.sender != address(systemContract)) {
            revert SenderNotSystemContract(msg.sender);
        }

        // Extract metadata from message 
        address senderEvmAddress = BytesHelperLib.bytesToAddress(message, 0);
        address targetZRC20 = BytesHelperLib.bytesToAddress(message, 20);

        // Fetch zrc20 token price into currentPrice
        bytes[] memory updateData;
        uint256 updateFee = pythNetwork.getUpdateFee(updateData);
        pythNetwork.updatePriceFeeds{value : updateFee}(updateData);
        PythStructs.Price memory currentPriceStruct = pythNetwork.getPrice(addressToPriceFeed[zrc20]);
        uint256 currentPrice = convertToUint(currentPriceStruct, IZRC20Metadata(zrc20).decimals());
        emit EddyRewards(zrc20, currentPrice, senderEvmAddress);
        // we could also emit out the exact dollar denominated value, but can also do that offchain to save gas

        // need to think of rounding precision errors
        uint256 feeToCharge = ( amount * feeCharge ) / 10000 ; 
        
        // same token
        if (targetZRC20 == zrc20) {
            IZRC20(targetZRC20).transfer(owner(), feeToCharge);
            IZRC20(targetZRC20).transfer(senderEvmAddress, amount - feeToCharge);
        } else {
            // swap
            IZRC20(zrc20).transfer(owner(),feeToCharge);
            uint256 outputAmount = _swap(
                    zrc20,
                    amount - feeToCharge,
                    targetZRC20,
                    0
            );
            IZRC20(targetZRC20).transfer(senderEvmAddress, outputAmount);
        }
        emit EddyNativeTokenAssetDeposited(senderEvmAddress, amount, senderEvmAddress);
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

    function withdrawToNativeChain(
        bytes calldata withdrawData,
        uint256 amount,
        address zrc20,
        address targetZRC20
    ) external {
        bool isTargetZRC20BTC_ZRC20 = (targetZRC20 == BTC_ZRC20);
        address tokenToUse = (targetZRC20 == zrc20) ? zrc20 : targetZRC20;
        uint256 amountToUse = amount;

        // check for approval
        uint256 allowance = IZRC20(zrc20).allowance(msg.sender, address(this));
        require(allowance > amount, "Not enough allowance of ZRC20 token");

        IZRC20(zrc20).transferFrom(msg.sender, address(this), amount);

        if (targetZRC20 != zrc20) {
            // swap and update the amount
            amountToUse = _swap(
                zrc20,
                amount,
                targetZRC20,
                0
            );
        }

        // need to think of rounding precision errors
        uint256 feeToCharge = ( amount * feeCharge ) / 10000 ; 

        // understand how btc withdrawal works
        if (isTargetZRC20BTC_ZRC20) {
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(withdrawData, 0);
            (, uint256 gasFee) = IZRC20(tokenToUse).withdrawGasFee();
            IZRC20(tokenToUse).approve(tokenToUse, gasFee);
            if (amountToUse < gasFee) revert WrongAmount();
            IZRC20(tokenToUse).withdraw(recipientAddressBech32, amountToUse - gasFee);
        } else {
            // EVM withdraw
            bytes32 recipient = BytesHelperLib.addressToBytes(msg.sender);
            SwapHelperLib._doWithdrawal(
                tokenToUse,
                feeToCharge,
                recipient
            );
            SwapHelperLib._doWithdrawal(
                tokenToUse,
                amountToUse - feeToCharge,
                recipient
            );

        }

        emit EddyNativeTokenAssetWithdrawn(zrc20, amount, withdrawData);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL HELPER FUNCTIONS                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function convertToUint(
        PythStructs.Price memory price,
        uint8 targetDecimals
    ) private pure returns (uint256) {
        if (price.price < 0 || price.expo > 0 || price.expo < -255) {
            revert InvalidPrice();
        }

        uint8 priceDecimals = uint8(uint32(-1 * price.expo));

        if (targetDecimals >= priceDecimals) {
            return
                uint(uint64(price.price)) *
                10 ** uint32(targetDecimals - priceDecimals);
        } else {
            return
                uint(uint64(price.price)) /
                10 ** uint32(priceDecimals - targetDecimals);
        }
    }

    function _getRecipient(bytes calldata message) internal pure returns (bytes32 recipient) {
        address recipientAddr = BytesHelperLib.bytesToAddress(message, 0);
        recipient = BytesHelperLib.addressToBytes(recipientAddr);
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
}