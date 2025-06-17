// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RealEstateTokenization is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds
    bytes32 public constant PROPERTY_MANAGER_ROLE = keccak256("PROPERTY_MANAGER_ROLE
        string location;
        uint256 area; // in square meters
        uint256 valuation; // in wei (or USD equivalent)))
    function mintProperty(
        address to,
        string memory tokenURI,
        string memory location,
        uint256 area,
        uint256 valuation,
        string memory ipfsHash
    ) external onlyManager {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        propertyInfo[newTokenId] = PropertyDetails(location, area, valuation, ipfsHash);

        emit PropertyMinted(newTokenId, to, location, valuation);
    }

    function getPropertyDetails(uint256 tokenId) external view returns (PropertyDetails memory) {
        require(_exists(tokenId), "Property does not exist");
        return propertyInfo[tokenId];
    }

    function grantManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PROPERTY_MANAGER_ROLE, account);
    }

    function revokeManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PROPERTY_MANAGER_ROLE, account);
    }
}
