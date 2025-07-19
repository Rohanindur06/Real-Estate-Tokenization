// SPDX-License-Identifier: 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RealEstateTokenization is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

 
        uint256 area; // in square meters
        uint256 valuation; // in wei (or USD equivalen
    function mintProperty(
    
        _setTokenURI(newTokenId, tokenURI);
\\
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
