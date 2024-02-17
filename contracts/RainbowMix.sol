// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { ERC404 } from "./ERC404.sol";

/**
 * @title RainbowMix
 * @dev The RainbowMix contract is an ERC20 token is backed by NFTs. The contract allows the owner to transfer NFTs to this contract and bind them to ERC20 tokens.(STG 1)
 * STG 2 should be automated so everyone can add their NFTs to the contract and bind them to ERC20 tokens in return for a calculated amount of RBM tokens.
 */
contract RainbowMix is Ownable, ERC404 {
    // Array of allowed NFT addresses, which can be added by the owner
    address[] public allowedNftAddresses;

    // Mapping of ERC20 token ID to NFT token ID for transferred NFTs to this contract
    mapping(uint256 => uint256) public transferredNfts;

    // Mapping to store the address of the NFT contract for a given NFT token ID
    mapping(uint256 => address) private nftAddressForTokenId;

    constructor() ERC404("RainbowMix", "RBM", 18) Ownable(msg.sender) {
        _setERC721TransferExempt(msg.sender, true);
        _mintERC20(msg.sender, 10000 * units, false);
    }

    /**
     * @notice Returns the URI for a given token ID by checking if the token ID is associated with a transferred NFT
     * @param tokenId_ The ID of the token
     * @return The URI for the token
     */
    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        // If the token ID is in transferredNfts, construct the URI accordingly
        if (nftAddressForTokenId[tokenId_] != address(0)) {
            IERC721Metadata nftContract = IERC721Metadata(nftAddressForTokenId[tokenId_]);
            return nftContract.tokenURI(transferredNfts[tokenId_]);
        } else {
            // Fallback URI if the token ID is not associated with a transferred NFT
            return "https://example.com/default-token";
        }
    }

    function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

    /**
     * @notice Transfer an NFT to this contract and bind it to an ERC20 token
     * @param erc20TokenId The ID of the ERC20 token
     * @param nftTokenId The ID of the NFT token
     * @param nftAddress The address of the NFT contract
     */
    function transferNft(uint256 erc20TokenId, uint256 nftTokenId, address nftAddress) external onlyOwner {
        // Check if NFT address is allowed
        require(isNftAddressAllowed(nftAddress), "NFT address not allowed");
        // Transfer the NFT to this contract
        IERC721(nftAddress).transferFrom(msg.sender, address(this), nftTokenId);
        // Bind the NFT to the ERC20 token
        transferredNfts[erc20TokenId] = nftTokenId;
        nftAddressForTokenId[erc20TokenId] = nftAddress;
    }

    function addAllowedNftAddress(address nftAddress) external onlyOwner {
        allowedNftAddresses.push(nftAddress);
    }

    function isNftAddressAllowed(address nftAddress) public view returns (bool) {
        for (uint i = 0; i < allowedNftAddresses.length; i++) {
            if (allowedNftAddresses[i] == nftAddress) {
                return true;
            }
        }
        return false;
    }
}
