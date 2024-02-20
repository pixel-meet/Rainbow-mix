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
      const ercTokenId2 = 2001;
      const ercTokenId3 = 4001;
      const ercTokenId4 = 6001;
      const ercTokenId5 = 8001;
      const ercTokenId6 = 2;
      const nftTokenId = 10;
      const nftTokenId2 = 22;
      const nftTokenId3 = 23;
      const nftTokenId4 = 24;
      const nftTokenId5 = 25;
      const nftTokenId6 = 26;

      // Mint an NFT to the owner
      await mockNFT.mint(owner.address, nftTokenId);
      await mockNFT.mint(owner.address, nftTokenId2);
      await mockNFT.mint(owner.address, nftTokenId3);
      await mockNFT.mint(owner.address, nftTokenId4);
      await mockNFT.mint(owner.address, nftTokenId5);
      await mockNFT.mint(owner.address, nftTokenId6);

      // Approve the RainbowMix contract to transfer the NFT
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId);
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId2);
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId3);
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId4);
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId5);
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId6);
      // Add the MockNFT address to the list of allowed addresses
      await rainbowMix.updateAllowedNftAddress(mockNFT.address, true);
      await rainbowMix.allowTokenIds(mockNFT.address, [nftTokenId, nftTokenId2, nftTokenId3, nftTokenId4, nftTokenId5, nftTokenId6], true);

      // Transfer and bind the NFT
      await rainbowMix.transferNft(nftTokenId, mockNFT.address);
      await rainbowMix.transferNft(nftTokenId2, mockNFT.address);
      await rainbowMix.transferNft(nftTokenId3, mockNFT.address);
      await rainbowMix.transferNft(nftTokenId4, mockNFT.address);
      await rainbowMix.transferNft(nftTokenId5, mockNFT.address);
      await rainbowMix.transferNft(nftTokenId6, mockNFT.address);

      // Verify the binding
      expect(await rainbowMix.transferredNfts(ercTokenId)).to.equal(nftTokenId);
      expect(await rainbowMix.transferredNfts(ercTokenId2)).to.equal(nftTokenId2);
      expect(await rainbowMix.transferredNfts(ercTokenId3)).to.equal(nftTokenId3);
      expect(await rainbowMix.transferredNfts(ercTokenId4)).to.equal(nftTokenId4);
      expect(await rainbowMix.transferredNfts(ercTokenId5)).to.equal(nftTokenId5);
      expect(await rainbowMix.transferredNfts(ercTokenId6)).to.equal(nftTokenId6);
      expect(await mockNFT.ownerOf(nftTokenId)).to.equal(rainbowMix.address);
    });
  });

  describe("Reward Functionality", function () {
    // Existing tests...

    it("Prevents rewards claim before time lock expires", async function () {
      const { rainbowMix, mockNFT, addr1 } = await loadFixture(deployRainbowMixFixture);
      const nftTokenId = 2;
      const rewardAmount = 100;

      // Setup for reward claim
      await rainbowMix.addTransferNftReward([nftTokenId], mockNFT.address, rewardAmount);

      // Mint, approve, transfer NFT, and setup rewards as in previous tests
      await mockNFT.mint(addr1.address, nftTokenId);
      await mockNFT.connect(addr1).approve(rainbowMix.address, nftTokenId);

      // Add the MockNFT address to the list of allowed addresses
      await rainbowMix.updateAllowedNftAddress(mockNFT.address, true);
      await rainbowMix.allowTokenIds(mockNFT.address, [nftTokenId], true);

      await rainbowMix.connect(addr1).transferNft(nftTokenId, mockNFT.address);

      // Attempt to claim rewards before time lock expires
      await expect(rainbowMix.connect(addr1).claimRewards())
        .to.be.revertedWith("Time lock not expired");
    });

    it("Allows rewards claim after time lock expires", async function () {
      const { rainbowMix, mockNFT, addr1 } = await loadFixture(deployRainbowMixFixture);
      const nftTokenId = 2;
      const rewardAmount = 100;

      // Setup for reward claim as before
      await rainbowMix.addTransferNftReward([nftTokenId], mockNFT.address, rewardAmount);
      await mockNFT.mint(addr1.address, nftTokenId);
      await mockNFT.connect(addr1).approve(rainbowMix.address, nftTokenId);

      // Add the MockNFT address to the list of allowed addresses
      await rainbowMix.updateAllowedNftAddress(mockNFT.address, true);
      await rainbowMix.allowTokenIds(mockNFT.address, [nftTokenId], true);

      await rainbowMix.connect(addr1).transferNft(nftTokenId, mockNFT.address);

      // Fast forward time by 14 days + 1 second to simulate time lock expiry
      await mine(1209601); // 14 days * 24 hours * 60 minutes * 60 seconds + 1 second

      // Claim rewards after time lock expires
      await expect(rainbowMix.connect(addr1).claimRewards())
        .to.emit(rainbowMix, 'RewardsClaimed') // Assuming there's an event emitted on successful claim
        .withArgs(addr1.address, rewardAmount);

      // Verify the balance of addr1 to ensure they received the rewards
      const rewardsBalance = await rainbowMix.balanceOf(addr1.address);
      expect(rewardsBalance).to.equal(ethers.utils.parseUnits(rewardAmount.toString(), 18));
    });
  });


});
