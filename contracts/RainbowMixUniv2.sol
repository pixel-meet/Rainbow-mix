// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC404 } from "./ERC404.sol";
import "./lib/Redeem.sol";
import { ERC404UniswapV2Exempt } from "./ERC404UniswapV2Exempt.sol";

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

interface IMinimalTransfer {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IMinimalMetadata {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract RainbowMixUni is Ownable, ERC404, ERC404UniswapV2Exempt {
    using Redeem for Redeem.Redemption;
    Redeem.Redemption private redemption;

    mapping(address => bool) public allowedNftAddresses;
    mapping(uint256 => uint256) public transferredNfts;
    mapping(uint256 => address) private nftAddressForTokenId;
    mapping(address => uint256) public claimableRewards;
    mapping(address => uint256) public timeLock;
    mapping(address => mapping(uint256 => uint256)) public nftTransferRewards; // Mapping for rewards
    uint256 private totalRewardsAllocated; // Counter for total rewards allocated
    uint256 private _erc20TokenIdCounter = 0;
    uint256 private _groupCounter = 0;

    uint16 private constant GROUP_SIZE = 2000;
    uint16 private constant TOTAL_GROUPS = 5;
    uint16 private constant TOTAL_SUPPLY = GROUP_SIZE * TOTAL_GROUPS;
    uint16 private constant MAX_REWARDS = 4000;
    uint64 private constant REDEMTION_PERIOD = 120 days;

    uint256[TOTAL_GROUPS] private _idsAllocatedInGroup;

    struct AllowedTokenInfo {
        bool allowAllTokens;
        mapping(uint256 => bool) specificAllowedTokens;
    }

    mapping(address => AllowedTokenInfo) private allowedTokenInfos;
    bool public canRedeem = true; // if anything goes wrong, we start with a redeemable state

    event NftTransferred(uint256 indexed erc20TokenId, uint256 indexed nftTokenId, address nftAddress);
    event RewardsClaimed(address indexed account, uint256 amount);
    event NFTClaimed(address indexed account, uint256 indexed erc20TokenId, address nftAddress, uint256 nftTokenId);

    //0x7a250d5630b4cf539739df2c5dacb4c659f2488d Router address
    constructor(
        address uniswapV2Router_
    ) ERC404("RainbowMix", "RBM", 18) Ownable(msg.sender) ERC404UniswapV2Exempt(uniswapV2Router_) {
        _setERC721TransferExempt(msg.sender, true);
        _mintERC20(msg.sender, (TOTAL_SUPPLY - MAX_REWARDS) * units);
        redemption.initialize(REDEMTION_PERIOD);
    }

    function disableRedemption() external onlyOwner {
        canRedeem = false;
    }

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

    function _getNextTokenId() private returns (uint256) {
        if (_erc20TokenIdCounter >= GROUP_SIZE * TOTAL_GROUPS) revert MaxSupplyReached();
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

    function transferNft(uint256 nftTokenId, address nftAddress) external {
        if (!allowedNftAddresses[nftAddress]) revert NftAddressNotAllowed();
        AllowedTokenInfo storage allowedInfo = allowedTokenInfos[nftAddress];
        if (!(allowedInfo.allowAllTokens || allowedInfo.specificAllowedTokens[nftTokenId])) revert TokenIdNotAllowed();
        if (_erc20TokenIdCounter >= TOTAL_SUPPLY) revert MaxNftsReached();

        _transferNftAndBind(nftTokenId, nftAddress);

        uint256 reward = nftTransferRewards[nftAddress][nftTokenId];
        if (reward > 0) {
            claimableRewards[msg.sender] += reward;
            timeLock[msg.sender] = block.timestamp + 14 days;
        }
    }

    function claimRewards() external {
        if (block.timestamp < timeLock[msg.sender]) revert TimeLockNotExpired();
        uint256 reward = claimableRewards[msg.sender];
        if (reward <= 0) revert NoRewardsToClaim();

        _mintERC20(msg.sender, reward * units);
        claimableRewards[msg.sender] = 0;
        timeLock[msg.sender] = 0;

        emit RewardsClaimed(msg.sender, reward);
    }

    function directTransferNfts(uint256[] calldata nftTokenIds, address[] calldata nftAddresses) external onlyOwner {
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            _transferNftAndBind(nftTokenIds[i], nftAddresses[i]);
        }
    }

    function updateAllowedNftAddress(address nftAddress, bool allowed) external onlyOwner {
        allowedNftAddresses[nftAddress] = allowed;
    }

    function allowTokenIds(address nftAddress, uint256[] calldata tokenIds, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            allowedTokenInfos[nftAddress].specificAllowedTokens[tokenIds[i]] = allowed;
        }
    }

    function setAllowAllTokens(address nftAddress, bool allow) external onlyOwner {
        allowedTokenInfos[nftAddress].allowAllTokens = allow;
    }

    function addTransferNftReward(uint256[] calldata tokenIds, address nftAddress, uint256 amount) external onlyOwner {
        if (totalRewardsAllocated + amount * tokenIds.length > MAX_REWARDS) revert MaxSupplyReached();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftTransferRewards[nftAddress][tokenIds[i]] = amount;
        }
        totalRewardsAllocated += amount * tokenIds.length;
    }

    function emergencyRedeem(uint256 nftTokenId, address nftAddress) external onlyOwner {
        if (!canRedeem) revert RedemptionDisabled();
        if (nftAddressForTokenId[nftTokenId] != nftAddress) revert NftDoesNotMatchStoredAddress();
        IMinimalTransfer nftContract = IMinimalTransfer(nftAddress);

        nftContract.transferFrom(address(this), owner(), nftTokenId);

        delete nftAddressForTokenId[nftTokenId];
    }

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

    function startRedemption(uint256 tokenId) public {
        redemption.startRedemption(tokenId);
    }
}
