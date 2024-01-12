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
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";
import "@zetachain/toolkit/contracts/SwapHelperLib.sol";
import {IZRC20Metadata} from  "@zetachain/protocol-contracts/contracts/zevm/Interfaces.sol";

// pyth dependencies
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

// oz dependencies
import "@openzeppelin/contracts/access/Ownable.sol";

/// @author proxima424 <https://github.com/proxima424>
/// @author add abhishek's creds
contract EddyCrossChainSwapV1 is zContract, Ownable {

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
    event FeeChanged(uint256 indexed oldBP, uint256 indexed newBP);

    /// @dev do optimizations here
    // also have to include swap amount @ask
    event EddyCrossChainSwap(address zrc20, address targetZRC20,uint256 amount, uint256 finalOutputAmount, address evmWalletAddress, uint feeCharged, uint dollarValue,bytes32 indexed recipient);

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
    function setFeeCharge(uint256 _newFeeCharge) external onlyOwner {
        emit FeeChanged(feeCharge,_newFeeCharge);
        feeCharge = _newFeeCharge;     
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   CORE FUNCTIONS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        if (msg.sender != address(systemContract)) {
            revert SenderNotSystemContract(msg.sender);
        }

        // Extract metadata from input
        bytes32 recipient = getRecipientOnly(message);
        address targetZRC20 = getTargetOnly(message);
        uint256 minAmt = 0;
        address evmWalletAddress;

        // Fetch zrc20 token price into currentPrice
        bytes[] memory updateData;
        uint256 updateFee = pythNetwork.getUpdateFee(updateData);
        pythNetwork.updatePriceFeeds{value : updateFee}(updateData);
        PythStructs.Price memory currentPriceStruct = pythNetwork.getPrice(addressToPriceFeed[zrc20]);
        uint256 currentPrice = convertToUint(currentPriceStruct, IZRC20Metadata(zrc20).decimals());
        // should the rewards be accounted for recipient?

        // need to think of rounding precision errors
        uint256 feeToCharge = ( amount * feeCharge ) / 10000 ; 

        // Send fees to owner()
        IZRC20(zrc20).transfer(owner(), feeToCharge);

        uint256 outputAmount;
        uint256 finalOutputAmount;

         if (targetZRC20 == BTC_ZRC20) {
            
            bytes memory recipientAddressBech32 = bytesToBech32Bytes(message, 20);
            outputAmount = _swap(
                zrc20,
                amount-feeToCharge,
                targetZRC20,
                minAmt
            );
            (, uint256 gasFee) = IZRC20(targetZRC20).withdrawGasFee();
            IZRC20(targetZRC20).approve(targetZRC20, gasFee);
            if (outputAmount < gasFee) revert WrongAmount();

            IZRC20(targetZRC20).withdraw(recipientAddressBech32, outputAmount - gasFee);
            evmWalletAddress = BytesHelperLib.bytesToAddress(context.origin, 0);
        } else {
            outputAmount = _swap(
                zrc20,
                amount-feeToCharge,
                targetZRC20,
                minAmt
            );
            SwapHelperLib._doWithdrawal(targetZRC20, outputAmount, recipient);
            evmWalletAddress = BytesHelperLib.bytesToAddress(message, 20);
        }
        // @show changed this event
        emit EddyCrossChainSwap(zrc20,targetZRC20,amount,outputAmount,evmWalletAddress,feeToCharge,currentPrice,getRecipientOnly(message));
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


}