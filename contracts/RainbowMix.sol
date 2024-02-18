// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { ERC404 } from "./ERC404.sol";

contract RainbowMix is Ownable, ERC404 {
    mapping(address => bool) public allowedNftAddresses;
    mapping(uint256 => uint256) public transferredNfts;
    mapping(uint256 => address) private nftAddressForTokenId;
    uint256 private _erc20TokenIdCounter;
    mapping(address => mapping(uint256 => uint256)) public nftTransferRewards; // Mapping for rewards
    uint256 private totalRewardsAllocated; // Counter for total rewards allocated
    uint16 private constant TOTAL_SUPPLY = 10000;
    uint256 private constant MAX_REWARDS = 4000; // Maximum rewards allowed in total, assuming the token has 18 decimals

    struct AllowedTokenInfo {
        bool allowAllTokens;
        mapping(uint256 => bool) specificAllowedTokens;
    }

    mapping(address => AllowedTokenInfo) private allowedTokenInfos;
    bool public canRedeem = true; // if anything goes wrong, we start with a redeemable state

    event NftTransferred(uint256 indexed erc20TokenId, uint256 indexed nftTokenId, address nftAddress);

    constructor() ERC404("RainbowMix", "RBM", 18) Ownable(msg.sender) {
        _setERC721TransferExempt(msg.sender, true);
        _mintERC20(msg.sender, (TOTAL_SUPPLY - MAX_REWARDS) * units, false);
    }

    /**
     * @notice to disable the redemption of NFTs by the owner to prevent any potential abuse
     */
    function disableRedemption() external onlyOwner {
        canRedeem = false;
    }

    /**
     * @notice Returns the URI for a given token ID by checking if the token ID is associated with a transferred NFT
     * @param tokenId_ The ID of the token
     * @return The URI for the token
     */
    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        if (nftAddressForTokenId[tokenId_] != address(0)) {
            IERC721Metadata nftContract = IERC721Metadata(nftAddressForTokenId[tokenId_]);
            return nftContract.tokenURI(transferredNfts[tokenId_]);
        } else {
            return "https://raw.githubusercontent.com/pixel-meet/Rainbow-mix/main/default.json";
        }
    }

    function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

    /**
     * @notice Transfer an NFT to this contract and bind it to an ERC20 token
     * @param nftTokenId The ID of the NFT token
     * @param nftAddress The address of the NFT contract
     */
    function transferNft(uint256 nftTokenId, address nftAddress) external {
        require(allowedNftAddresses[nftAddress], "NFT address not allowed");
        require(
            allowedTokenInfos[nftAddress].allowAllTokens ||
                allowedTokenInfos[nftAddress].specificAllowedTokens[nftTokenId],
            "Token ID not allowed"
        );
        require(_erc20TokenIdCounter < TOTAL_SUPPLY, "Maximum number of NFTs reached");

        IERC721Metadata nftContract = IERC721Metadata(nftAddress);
        nftContract.transferFrom(msg.sender, address(this), nftTokenId);

        _erc20TokenIdCounter++;
        uint256 erc20TokenId = _erc20TokenIdCounter;

        transferredNfts[erc20TokenId] = nftTokenId;
        nftAddressForTokenId[erc20TokenId] = nftAddress;

        uint256 reward = nftTransferRewards[nftAddress][nftTokenId];
        if (reward > 0) {
            _mintERC20(msg.sender, reward * units, false);
        }

        emit NftTransferred(erc20TokenId, nftTokenId, nftAddress);
    }

    /**
     * @notice Set whether a specific NFT contract is allowed (donation or OTC)
     * @param nftAddress The address of the NFT contract
     * @param allowed Whether the NFT contract is allowed
     */
    function updateAllowedNftAddress(address nftAddress, bool allowed) external onlyOwner {
        allowedNftAddresses[nftAddress] = allowed;
    }

    /**
     * @notice Set whether a specific token ID is allowed for a given NFT contract (donation or OTC)
     * @param nftAddress The address of the NFT contract
     * @param tokenIds The IDs of the NFT tokens
     * @param allowed Whether the tokens are allowed
     */
    function allowTokenIds(address nftAddress, uint256[] calldata tokenIds, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            allowedTokenInfos[nftAddress].specificAllowedTokens[tokenIds[i]] = allowed;
        }
    }

    /**
     * @notice Set whether all tokens are allowed for a given NFT contract (donation or OTC)
     * @param nftAddress The address of the NFT contract
     * @param allow Whether all tokens are allowed
     */
    function setAllowAllTokens(address nftAddress, bool allow) external onlyOwner {
        allowedTokenInfos[nftAddress].allowAllTokens = allow;
    }

    /**
     * @notice Add rewards for transferring NFTs
     * @param tokenIds The IDs of the NFT tokens
     * @param nftAddress The address of the NFT contract
     * @param amount The amount of rewards to add
     */
    function addTransferNftReward(uint256[] calldata tokenIds, address nftAddress, uint256 amount) external onlyOwner {
        require(totalRewardsAllocated + amount * tokenIds.length <= MAX_REWARDS, "Exceeds maximum rewards limit");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftTransferRewards[nftAddress][tokenIds[i]] = amount;
        }
        totalRewardsAllocated += amount * tokenIds.length;
    }

    /**
     * @notice Allows the contract owner to redeem an NFT held by the contract. IMPORTANT to trust the owner.
     * @param nftTokenId The ID of the NFT to redeem.
     * @param nftAddress The address of the NFT contract.
     */
    function emergencyRedeemNft(uint256 nftTokenId, address nftAddress) external onlyOwner {
        require(canRedeem, "Redemption is disabled");
        require(nftAddressForTokenId[nftTokenId] == nftAddress, "NFT does not match stored address");
        IERC721 nftContract = IERC721(nftAddress);

        // Transfer the NFT from the contract to the owner.
        nftContract.transferFrom(address(this), owner(), nftTokenId);

        delete nftAddressForTokenId[nftTokenId];
    }
}
