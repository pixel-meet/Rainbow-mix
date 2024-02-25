// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC404 } from "./ERC404.sol";
import { ERC404UniswapV2Exempt } from "./ERC404UniswapV2Exempt.sol";
import "./lib/Redeem.sol";

error MaxSupplyReached();
error NftAddressNotAllowed();
error TokenIdNotAllowed();
error MaxNftsReached();
error NoRewardsToClaim();
error TimeLockNotExpired();
error RedemptionDisabled();
error NftDoesNotMatchStoredAddress();
error NoNftAssociatedWithToken();
error NotTheTokenOwner();
error RedemptionPeriodNotPassed();
error ClaimTimeLockNotPassed();
error InvalidRedemptionPeriod();

interface IMinimalTransfer {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IMinimalMetadata {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/**
 * @title RainbowMix
 * @dev The RainbowMix contract is an ERC20 token is backed by NFTs. The contract allows the owner to transfer NFTs to this contract and bind them to ERC20 tokens.
 */
contract RainbowMixUni is Ownable, ERC404, ERC404UniswapV2Exempt {
    using Redeem for Redeem.Redemption;
    Redeem.Redemption private redemption;

    // Mapping of ERC20 IDs to NFT IDs for transferred NFTs to this contract
    mapping(uint256 => uint256) public transferredNfts;
    // Mapping to store the address of the NFT contract for a given NFT token ID
    mapping(uint256 => address) private nftAddressForTokenId;
    // Mapping for rewards for transferring NFTs
    mapping(address => uint256) public claimableRewards;
    // Mapping for time-locked rewards so they can't be claimed immediately
    mapping(address => uint256) public timeLock;
    // Mapping for rewards for transferring NFTs
    mapping(address => mapping(uint256 => uint256)) public nftTransferRewards;
    // Counter for total rewards allocated, to ensure it doesn't exceed the maximum
    uint256 private totalRewardsAllocated;
    // Counter for the total number of transferred NFTs
    uint256 private _totalTransferCounter = 0;

    // Grouping is used to create a random bounding of NFTs across the ERC20 tokens so is not predictable
    uint256 private _groupCounter = 0;
    uint16 private constant GROUP_SIZE = 2000;
    uint16 private constant TOTAL_GROUPS = 5;
    uint256[TOTAL_GROUPS] private _idsAllocatedInGroup;

    // General constants for the contract
    uint16 private constant TOTAL_SUPPLY = GROUP_SIZE * TOTAL_GROUPS;
    uint16 private constant MAX_REWARDS = 4000;
    uint64 private constant MAX_CLAIM_TIME_LOCK = 7 days;
    uint64 private constant MAX_REDEMTION_PERIOD = 360 days;
    uint64 private constant MIN_REDEMTION_PERIOD = 60 days;
    
    uint64 private claimTimeLock = 1 days;

    struct AllowedTokenInfo {
        bool allowAllTokens;
        mapping(uint256 => bool) specificAllowedTokens;
    }

    mapping(address => AllowedTokenInfo) private allowedTokenInfos;
    bool public canRedeem = true; // OPTIONAL - to disable the redemption feature if something went wrong(Only owner)

    event NftTransferred(uint256 indexed erc20TokenId, uint256 indexed nftTokenId, address nftAddress);
    event RewardsClaimed(address indexed account, uint256 amount);
    event NFTClaimed(address indexed account, uint256 indexed erc20TokenId, address nftAddress, uint256 nftTokenId);
    event RedemptionStarted(uint256 indexed erc20TokenId);

    //0x7a250d5630b4cf539739df2c5dacb4c659f2488d Router address
    constructor(
        address uniswapV2Router_
    ) ERC404("RainbowMix", "RBM", 18) Ownable(msg.sender) ERC404UniswapV2Exempt(uniswapV2Router_) {
        _setERC721TransferExempt(msg.sender, true);
        _mintERC20(msg.sender, (TOTAL_SUPPLY - MAX_REWARDS) * units);
        redemption.initialize(60 days);
    }

    /**
     * @notice Disables the ability to redeem NFTs for the owner of the contract
     */
    function disableRedemption() external onlyOwner {
        canRedeem = false;
    }

    /**
     * @notice Set the claim time lock for rewards
     * @param timeLock_ The time lock for rewards
     */
    function setClaimTimeLock(uint64 timeLock_) external onlyOwner {
        if (timeLock_ > MAX_CLAIM_TIME_LOCK) revert ClaimTimeLockNotPassed();
        claimTimeLock = timeLock_;
    }

    /**
     * @notice Set the redemption period for the contract
     * @param period The redemption period
     */
    function setRedemptionPeriod(uint64 period) external onlyOwner {
        if (period > MAX_REDEMTION_PERIOD || period < MIN_REDEMTION_PERIOD) revert InvalidRedemptionPeriod();
        redemption.initialize(period);
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
     * @notice Determine the next ERC20 Token ID bound to the transfered NFT, going through the groups for a more random distribution
     * @return The total supply
     */
    function _getNextTokenId() private returns (uint256) {
        if (_totalTransferCounter >= GROUP_SIZE * TOTAL_GROUPS) revert MaxSupplyReached();
        uint256 startIdOfGroup = _groupCounter * GROUP_SIZE + 1;
        uint256 nextIdInGroup = startIdOfGroup + _idsAllocatedInGroup[_groupCounter];
        _idsAllocatedInGroup[_groupCounter]++;
        _totalTransferCounter++;
        _groupCounter = (_groupCounter + 1) % TOTAL_GROUPS;

        return nextIdInGroup;
    }

    /**
     * @notice Transfer an NFT to this contract and bind it to an ERC20 token
     * @param nftTokenId The ID of the NFT token
     * @param nftAddress The address of the NFT contract
     */
    function _transferNftAndBind(uint256 nftTokenId, address nftAddress) internal {
        IMinimalTransfer(nftAddress).transferFrom(msg.sender, address(this), nftTokenId);

        uint256 erc20TokenId = _getNextTokenId();
        transferredNfts[erc20TokenId] = nftTokenId;
        nftAddressForTokenId[erc20TokenId] = nftAddress;

        emit NftTransferred(erc20TokenId, nftTokenId, nftAddress);
    }

    /**
     * @notice Add rewards for transferring specific NFTs
     * @param tokenIds The IDs of the NFT tokens
     * @param nftAddress The address of the NFT contract
     * @param amount The amount of rewards
     */
    function addTransferNftReward(uint256[] calldata tokenIds, address nftAddress, uint256 amount) external onlyOwner {
        if (totalRewardsAllocated + amount * tokenIds.length > MAX_REWARDS) revert MaxSupplyReached();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftTransferRewards[nftAddress][tokenIds[i]] = amount;
        }
        totalRewardsAllocated += amount * tokenIds.length;
    }

    /**
     * @notice Transfer an NFT to this contract and bind it to an ERC20 token
     * @param nftTokenId The ID of the NFT token
     * @param nftAddress The address of the NFT contract
     */
    function transferNft(uint256 nftTokenId, address nftAddress) external {
        AllowedTokenInfo storage allowedInfo = allowedTokenInfos[nftAddress];
        if (!(allowedInfo.allowAllTokens || allowedInfo.specificAllowedTokens[nftTokenId])) revert TokenIdNotAllowed();
        if (_totalTransferCounter >= TOTAL_SUPPLY) revert MaxNftsReached();

        _transferNftAndBind(nftTokenId, nftAddress);

        uint256 reward = nftTransferRewards[nftAddress][nftTokenId];
        if (reward > 0) {
            // if claim lock is 0 days direct transfer the reward to the user
            if (claimTimeLock == 0) {
                _mintERC20(msg.sender, reward * units);
                emit RewardsClaimed(msg.sender, reward);
            } else {
                claimableRewards[msg.sender] += reward;
                timeLock[msg.sender] = block.timestamp + claimTimeLock;
            }
        }
    }

    /**
     * @notice Claim the time-locked rewards
     */
    function claimRewards() external {
        if (block.timestamp < timeLock[msg.sender]) revert TimeLockNotExpired();
        uint256 reward = claimableRewards[msg.sender];
        if (reward <= 0) revert NoRewardsToClaim();

        _mintERC20(msg.sender, reward * units);
        claimableRewards[msg.sender] = 0;
        timeLock[msg.sender] = 0;

        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Directly transfer NFTs to the contract and bind them to ERC20 tokens by the owner.
     * @param nftTokenIds The IDs of the NFT tokens
     * @param nftAddresses The addresses of the NFT contracts
     */
    function directTransferNfts(uint256[] calldata nftTokenIds, address[] calldata nftAddresses) external onlyOwner {
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            _transferNftAndBind(nftTokenIds[i], nftAddresses[i]);
        }
    }

    /**
     * @notice Allow or disallow specific NFT tokens to be transferred
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
     * @notice Allow or disallow all NFT tokens of a contract to be transferred (Donation purpose)
     * @param nftAddress The address of the NFT contract
     * @param allow Whether all tokens are allowed
     */
    function setAllowAllTokens(address nftAddress, bool allow) external onlyOwner {
        allowedTokenInfos[nftAddress].allowAllTokens = allow;
    }

    /**
     * @notice OPTIONAL: In case something went wrong. BUT we can disable it forever with the disableRedemption function
     * @param nftTokenId The IDs of the NFT tokens
     * @param nftAddress The address of the NFT contract
     */
    function emergencyRedeem(uint256 nftTokenId, address nftAddress) external onlyOwner {
        if (!canRedeem) revert RedemptionDisabled();
        if (nftAddressForTokenId[nftTokenId] != nftAddress) revert NftDoesNotMatchStoredAddress();
        IMinimalTransfer nftContract = IMinimalTransfer(nftAddress);

        nftContract.transferFrom(address(this), owner(), nftTokenId);

        delete nftAddressForTokenId[nftTokenId];
    }

    /**
     * @notice Claim the NFT associated with an ERC20 token. Will only work if the redemption period has passed
     * @param erc20TokenId The ID of the ERC20 token
     */
    function claimNFT(uint256 erc20TokenId) public {
        if (!redemption.canRedeem(erc20TokenId)) revert RedemptionPeriodNotPassed();
        if (nftAddressForTokenId[erc20TokenId] == address(0)) revert NoNftAssociatedWithToken();
        if (ownerOf(erc20TokenId) != msg.sender) revert NotTheTokenOwner();

        address nftAddress = nftAddressForTokenId[erc20TokenId];
        uint256 nftTokenId = transferredNfts[erc20TokenId];

        IMinimalTransfer(nftAddress).transferFrom(address(this), msg.sender, nftTokenId);
        redemption.clearRedemption(erc20TokenId);

        delete transferredNfts[erc20TokenId];
        delete nftAddressForTokenId[erc20TokenId];

        emit NFTClaimed(msg.sender, erc20TokenId, nftAddress, nftTokenId);
    }

    /**
     * @notice Start the redemption period for an ERC20 token
     * @param tokenId The ID of the ERC20 token
     */
    function startRedemption(uint256 tokenId) public {
        redemption.startRedemption(tokenId);
        emit RedemptionStarted(tokenId);
    }
}
