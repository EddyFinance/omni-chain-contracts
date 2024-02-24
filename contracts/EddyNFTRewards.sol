// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EddyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping (address => bool) _claimableAddresses;
    mapping (address => bool) _minted;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function mintNFT(string memory tokenURI)
        public
        returns (uint256)
    {
        require(_claimableAddresses[msg.sender], "NFT_NOT_CLAIMABLE");
        require(!_minted[msg.sender], "Already minted NFT");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        _minted[msg.sender] = true;

        return newItemId;
    }

    function setClaimable(address[] memory wallets) external onlyOwner{
        for (uint i = 0; i < wallets.length; i++) {
            _claimableAddresses[wallets[i]] = true;
        }
    }
}