// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
 * Simple Real-Estate Tokenization Example
 * - PropertyNFT: ERC721 representing a property deed
 * - FractionalToken: ERC20 representing fractional ownership (shares)
 * - Fractionalizer: locks NFT, deploys FractionalToken, sells shares
 *
 * NOTES:
 * - Educational example only. Not production-audited.
 * - Real projects need legal/KYC, off-chain IPFS metadata, governance, panics, upgradeability & audits.
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @notice ERC721 property deed
contract PropertyNFT is ERC721URIStorage, Ownable {
    uint256 private _nextId = 1;

    constructor() ERC721("RealProperty", "PROP") {}

    /// @notice Mint a property NFT (owner only)
    function mintProperty(address to, string memory tokenURI) external onlyOwner returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        _setTokenURI(id, tokenURI);
        return id;
    }
}

/// @notice ERC20 fractional token for a single property
contract FractionalToken is ERC20, Ownable {
    uint8 private _decimalsOverride;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address initialHolder_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimalsOverride = decimals_;
        _mint(initialHolder_, totalSupply_);
        transferOwnership(initialHolder_); // make the initial holder the owner for admin ops
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimalsOverride;
    }

    /// @notice emergency burn by owner (optional)
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }
}

/// @notice Manager to fractionalize properties
contract Fractionalizer is Ownable, ReentrancyGuard {
    struct Offering {
        address nftAddress;
        uint256 tokenId;
        address fractionalToken;
        uint256 totalShares;        // in token smallest units (taking decimals into account)
        uint256 pricePerShareWei;   // price in wei per 1 share unit (smallest ERC20 unit)
        address seller;             // original owner who fractionalized
        bool active;
    }

    uint256 public nextOfferingId;
    mapping(uint256 => Offering) public offerings;

    event Fractionalized(uint256 indexed offeringId, address indexed seller, address fractionalToken);
    event SharesBought(uint256 indexed offeringId, address indexed buyer, uint256 amount, uint256 cost);

    /// @notice Fractionalize an NFT: transfer NFT to this contract and deploy an ERC20 for shares
    /// @param nftAddr address of PropertyNFT
    /// @param tokenId id of the NFT to lock
    /// @param name name of fractional ERC20
    /// @param symbol symbol of fractional ERC20
    /// @param totalShares total token supply (in whole tokens, decimals applied)
    /// @param decimals decimals for fractional ERC20
    /// @param pricePerShareWei price per smallest token unit (wei)
    function fractionalize(
        address nftAddr,
        uint256 tokenId,
        string calldata name,
        string calldata symbol,
        uint256 totalShares,
        uint8 decimals,
        uint256 pricePerShareWei
    ) external nonReentrant returns (uint256) {
        // Transfer NFT to this contract (seller must have approved)
        ERC721URIStorage nft = ERC721URIStorage(nftAddr);
        require(nft.ownerOf(tokenId) == msg.sender, "not nft owner");
        nft.transferFrom(msg.sender, address(this), tokenId);

        // Deploy fractional token and mint all shares to this contract for sale
        uint256 totalSupply = totalShares * (10 ** decimals);
        FractionalToken ft = new FractionalToken(name, symbol, totalSupply, address(this), decimals);

        // Save offering metadata
        uint256 id = nextOfferingId++;
        offerings[id] = Offering({
            nftAddress: nftAddr,
            tokenId: tokenId,
            fractionalToken: address(ft),
            totalShares: totalSupply,
            pricePerShareWei: pricePerShareWei,
            seller: msg.sender,
            active: true
        });

        emit Fractionalized(id, msg.sender, address(ft));
        return id;
    }

    /// @notice Buy fractional shares (payable). Buyer receives shares from contract's balance.
    /// @param offeringId id of offering
    /// @param shareAmount number of smallest token units to buy (includes decimals)
    function buyShares(uint256 offeringId, uint256 shareAmount) external payable nonReentrant {
        Offering storage o = offerings[offeringId];
        require(o.active, "not active");
        require(shareAmount > 0, "zero amount");
        require(shareAmount <= ERC20(o.fractionalToken).balanceOf(address(this)), "not enough shares");

        uint256 cost = shareAmount * o.pricePerShareWei;
        require(msg.value >= cost, "insufficient ETH sent");

        // Transfer funds (ETH) to seller immediately
        (bool sent, ) = payable(o.seller).call{value: cost}("");
        require(sent, "payment failed");

        // refund any extra
        if (msg.value > cost) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - cost}("");
            require(refunded, "refund failed");
        }

        // Transfer fractional tokens to buyer
        ERC20(o.fractionalToken).transfer(msg.sender, shareAmount);

        emit SharesBought(offeringId, msg.sender, shareAmount, cost);
    }

    /// @notice Seller can reclaim NFT if all shares are burned or returned to contract
    function reclaimIfFullyUnsold(uint256 offeringId) external nonReentrant {
        Offering storage o = offerings[offeringId];
        require(o.seller == msg.sender, "not seller");
        require(o.active, "not active");

        // If contract still holds all supply, seller can reclaim NFT
        uint256 bal = ERC20(o.fractionalToken).balanceOf(address(this));
        require(bal == o.totalShares, "shares already sold");

        // transfer NFT back to seller
        ERC721URIStorage(o.nftAddress).transferFrom(address(this), o.seller, o.tokenId);

        // mark inactive
        o.active = false;
    }

    /// @notice Emergency: admin can withdraw ERC20 tokens accidentally sent here (not the fractional contract)
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        ERC20(token).transfer(to, amount);
    }

    /// @notice Get offering summary
    function offeringInfo(uint256 offeringId) external view returns (Offering memory) {
        return offerings[offeringId];
    }
}
