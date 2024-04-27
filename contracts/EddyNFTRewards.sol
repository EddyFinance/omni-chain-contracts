// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EddyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address ADMIN = 0x7E1F80e8990a34b7FEebB530dCB46Dc3FB483377;    
    
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function mintNFT(
        address recipient,
        string memory tokenURI,
        bytes calldata signature
    )
        public
        returns (uint256)
    {   
        bytes32 message = prefixed(keccak256(abi.encodePacked(
            recipient, 
            tokenURI
        )));
        require(recoverSigner(message, signature) == ADMIN , 'INVALID_SIGNATURE');
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }

  function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(
      '\x19Ethereum Signed Message:\n32', 
      hash
    ));
  }

  function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
  {
    uint8 v;
    bytes32 r;
    bytes32 s;
  
    (v, r, s) = splitSignature(sig);
  
    return ecrecover(message, v, r, s);
  }
    function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8, bytes32, bytes32)
  {
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

}