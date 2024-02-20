// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC404 } from "./ERC404.sol";
import { ERC404UniswapV2Exempt } from "./ERC404UniswapV2Exempt.sol";

interface IMinimalTransfer {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IMinimalMetadata {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract RainbowMix is Ownable, ERC404, ERC404UniswapV2Exempt {
    mapping(address => bool) public allowedNftAddresses;
    mapping(uint256 => uint256) public transferredNfts;
    mapping(uint256 => address) private nftAddressForTokenId;
    mapping(address => uint256) public claimableRewards;
    mapping(address => uint256) public timeLock;
    mapping(address => mapping(uint256 => uint256)) public nftTransferRewards; // Mapping for rewards
    uint256 private totalRewardsAllocated; // Counter for total rewards allocated
    uint256 private _erc20TokenIdCounter = 0;
    uint256 private _groupCounter = 0;

    uint256 private constant GROUP_SIZE = 2000;
    uint256 private constant TOTAL_GROUPS = 5;
    uint256 private constant TOTAL_SUPPLY = GROUP_SIZE * TOTAL_GROUPS;
    uint256 private constant MAX_REWARDS = 4000; // Maximum rewards allowed in total, assuming the token has 18 decimals

    uint256[TOTAL_GROUPS] private _idsAllocatedInGroup;
    
    struct AllowedTokenInfo {
        bool allowAllTokens;
        mapping(uint256 => bool) specificAllowedTokens;
    }

    mapping(address => AllowedTokenInfo) private allowedTokenInfos;
    bool public canRedeem = true; // if anything goes wrong, we start with a redeemable state

    event NftTransferred(uint256 indexed erc20TokenId, uint256 indexed nftTokenId, address nftAddress);
    event RewardsClaimed(address indexed account, uint256 amount);

    //0x7a250d5630b4cf539739df2c5dacb4c659f2488d Router address
    constructor(
        address uniswapV2Router_
    ) ERC404("RainbowMix", "RBM", 18) Ownable(msg.sender) ERC404UniswapV2Exempt(uniswapV2Router_) {
        _setERC721TransferExempt(msg.sender, true);
        _mintERC20(msg.sender, (TOTAL_SUPPLY - MAX_REWARDS) * units);
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
            return IMinimalMetadata(nftAddressForTokenId[tokenId_]).tokenURI(transferredNfts[tokenId_]);
        } else {
            return "https://raw.githubusercontent.com/pixel-meet/Rainbow-mix/main/default.json";
        }
    }

    function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

    /**
     * @notice Get the next available token ID
     * @return The next available token ID
     */
    function _getNextTokenId() private returns (uint256) {
        require(_erc20TokenIdCounter < GROUP_SIZE * TOTAL_GROUPS, "Max supply reached");
        uint256 startIdOfGroup = _groupCounter * GROUP_SIZE + 1;
        uint256 nextIdInGroup = startIdOfGroup + _idsAllocatedInGroup[_groupCounter];
        _idsAllocatedInGroup[_groupCounter]++;
        _erc20TokenIdCounter++;
        _groupCounter = (_groupCounter + 1) % TOTAL_GROUPS;

        return nextIdInGroup;
    }

    function _transferNftAndBind(uint256 nftTokenId, address nftAddress) internal {
        IMinimalTransfer(nftAddress).transferFrom(msg.sender, address(this), nftTokenId);

        uint256 erc20TokenId = _getNextTokenId();
        transferredNfts[erc20TokenId] = nftTokenId;
        nftAddressForTokenId[erc20TokenId] = nftAddress;

        emit NftTransferred(erc20TokenId, nftTokenId, nftAddress);
    }

    /**
     * @notice Transfer an NFT to this contract and bind it to an ERC20 token, setting a reward for the transfer
     * @param nftTokenId The ID of the NFT token
     * @param nftAddress The address of the NFT contract
     */
    function transferNft(uint256 nftTokenId, address nftAddress) external {
        require(allowedNftAddresses[nftAddress], "NFT address not allowed");
        AllowedTokenInfo storage allowedInfo = allowedTokenInfos[nftAddress];
        require(allowedInfo.allowAllTokens || allowedInfo.specificAllowedTokens[nftTokenId], "Token ID not allowed");
        require(_erc20TokenIdCounter < TOTAL_SUPPLY, "Max NFTs reached");

        _transferNftAndBind(nftTokenId, nftAddress);

        uint256 reward = nftTransferRewards[nftAddress][nftTokenId];
        if (reward > 0) {
            claimableRewards[msg.sender] += reward;
            timeLock[msg.sender] = block.timestamp + 14 days;
        }
    }

    /**
     * @notice Claim rewards for transferring NFTs (after time lock 14 days)
     */
    function claimRewards() external {
        require(block.timestamp >= timeLock[msg.sender], "Time lock not expired");

        uint256 reward = claimableRewards[msg.sender];
        require(reward > 0, "No rewards to claim");

        _mintERC20(msg.sender, reward * units);
        claimableRewards[msg.sender] = 0;
        timeLock[msg.sender] = 0;

        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Transfer multiple NFTs to this contract and bind them to ERC20 tokens
     * @param nftTokenIds The IDs of the NFT tokens
     * @param nftAddresses The addresses of the NFT contracts
     */
    function directTransferNfts(uint256[] calldata nftTokenIds, address[] calldata nftAddresses) external onlyOwner {
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            _transferNftAndBind(nftTokenIds[i], nftAddresses[i]);
        }
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
        IMinimalTransfer nftContract = IMinimalTransfer(nftAddress);

        // Transfer the NFT from the contract to the owner.
        nftContract.transferFrom(address(this), owner(), nftTokenId);

        delete nftAddressForTokenId[nftTokenId];
    }
}
