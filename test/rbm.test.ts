import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture, mine } from "@nomicfoundation/hardhat-network-helpers";

describe("RainbowMix", function () {

  async function deployRainbowMixFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const RainbowMix = await ethers.getContractFactory("RainbowMix");
    const rainbowMix = await RainbowMix.deploy();

    const MockNFT = await ethers.getContractFactory("MockNFT");
    const mockNFT = await MockNFT.deploy("MockNFT", "MNFT");

    return { rainbowMix, mockNFT, owner, addr1, addr2, addrs };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { rainbowMix, owner } = await loadFixture(deployRainbowMixFixture);
      expect(await rainbowMix.owner()).to.equal(await owner.getAddress());
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const { rainbowMix, owner } = await loadFixture(deployRainbowMixFixture);
      const ownerBalance = await rainbowMix.balanceOf(await owner.getAddress());
      expect(await rainbowMix.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("NFT Binding", function () {
    it("Allows owner to add allowed NFT addresses", async function () {
      const { rainbowMix, mockNFT } = await loadFixture(deployRainbowMixFixture);
      await rainbowMix.updateAllowedNftAddress(mockNFT.address, true);
      expect(await rainbowMix.allowedNftAddresses(mockNFT.address)).to.be.true;
    });

    it("Prevents non-owners from adding allowed NFT addresses", async function () {
      const { rainbowMix, mockNFT, addr1 } = await loadFixture(deployRainbowMixFixture);
      await expect(rainbowMix.connect(addr1).updateAllowedNftAddress(mockNFT.address, true)).to.be.reverted;
    });

    it("Allows owner to transfer and bind an NFT to an ERC20 token", async function () {
      const { rainbowMix, mockNFT, owner } = await loadFixture(deployRainbowMixFixture);
      const ercTokenId = 1;
      const ercTokenId2 = 2;
      const nftTokenId = 10;
      const nftTokenId2 = 23;

      // Mint an NFT to the owner
      await mockNFT.mint(owner.address, nftTokenId);
      await mockNFT.mint(owner.address, nftTokenId2);

      // Approve the RainbowMix contract to transfer the NFT
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId);
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId2);

      // Add the MockNFT address to the list of allowed addresses
      await rainbowMix.updateAllowedNftAddress(mockNFT.address, true);
      await rainbowMix.allowTokenIds(mockNFT.address, [nftTokenId, nftTokenId2], true);

      // Transfer and bind the NFT
      await rainbowMix.transferNft(nftTokenId, mockNFT.address);
      await rainbowMix.transferNft(nftTokenId2, mockNFT.address);

      // Verify the binding
      expect(await rainbowMix.transferredNfts(ercTokenId)).to.equal(nftTokenId);
      expect(await rainbowMix.transferredNfts(ercTokenId2)).to.equal(nftTokenId2);
      expect(await mockNFT.ownerOf(nftTokenId)).to.equal(rainbowMix.address);
    });
  });

  describe("Reward Functionality", function () {
    it("Allows owner to add transfer rewards for NFTs", async function () {
      const { rainbowMix, mockNFT, owner } = await loadFixture(deployRainbowMixFixture);
      const tokenIds = [2];
      const rewardAmount = 100;

      // Initially, no rewards should be set for the NFT token ID
      expect(await rainbowMix.nftTransferRewards(mockNFT.address, 2)).to.equal(0);

      // Add rewards for transferring the specified NFT token ID
      await rainbowMix.addTransferNftReward(tokenIds, mockNFT.address, rewardAmount);

      // Verify that the rewards are correctly set
      expect(await rainbowMix.nftTransferRewards(mockNFT.address, 2)).to.equal(rewardAmount);
    });

    it("Correctly rewards users for transferring NFTs with rewards", async function () {
      const { rainbowMix, mockNFT, owner, addr1 } = await loadFixture(deployRainbowMixFixture);
      const nftTokenId = 2;
      const rewardAmount = 100;

      // Mint an NFT to the owner and add it to allowed addresses with rewards
      await mockNFT.mint(addr1.address, nftTokenId);
      await rainbowMix.updateAllowedNftAddress(mockNFT.address, true);
      await rainbowMix.allowTokenIds(mockNFT.address, [nftTokenId], true);
      await rainbowMix.addTransferNftReward([nftTokenId], mockNFT.address, 100);

      // Approve and transfer NFT to bind and receive rewards
      await mockNFT.connect(addr1).approve(rainbowMix.address, nftTokenId);
      await rainbowMix.connect(addr1).transferNft(nftTokenId, mockNFT.address);

      // Verify the owner received the reward tokens
      const ownerRewardBalance = await rainbowMix.balanceOf(await addr1.getAddress());
      expect(ownerRewardBalance).to.equal(ethers.utils.parseUnits("100", 18));
    });

    it("Prevents adding rewards that exceed the maximum limit", async function () {
      const { rainbowMix, mockNFT, owner } = await loadFixture(deployRainbowMixFixture);
      const tokenIds = [3, 4];
      const rewardAmount = 2001; // Exceeds the maximum limit * 2

      await expect(rainbowMix.addTransferNftReward(tokenIds, mockNFT.address, rewardAmount))
        .to.be.revertedWith("Exceeds maximum rewards limit");
    });
  });

});
