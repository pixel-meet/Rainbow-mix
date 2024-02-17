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
      await rainbowMix.addAllowedNftAddress(mockNFT.address);
      expect(await rainbowMix.isNftAddressAllowed(mockNFT.address)).to.be.true;
    });

    it("Prevents non-owners from adding allowed NFT addresses", async function () {
      const { rainbowMix, mockNFT, addr1 } = await loadFixture(deployRainbowMixFixture);
      await expect(rainbowMix.connect(addr1).addAllowedNftAddress(mockNFT.address)).to.be.reverted;
    });

    it("Allows owner to transfer and bind an NFT to an ERC20 token", async function () {
      const { rainbowMix, mockNFT, owner } = await loadFixture(deployRainbowMixFixture);
      const nftTokenId = 1;

      // Mint an NFT to the owner
      await mockNFT.mint(owner.address, nftTokenId);

      // Approve the RainbowMix contract to transfer the NFT
      await mockNFT.connect(owner).approve(rainbowMix.address, nftTokenId);

      // Add the MockNFT address to the list of allowed addresses
      await rainbowMix.addAllowedNftAddress(mockNFT.address);

      // Transfer and bind the NFT
      await rainbowMix.transferNft(nftTokenId, mockNFT.address);

      // Verify the binding
      expect(await rainbowMix.transferredNfts(nftTokenId)).to.equal(nftTokenId);
      expect(await mockNFT.ownerOf(nftTokenId)).to.equal(rainbowMix.address);
    });
  });

});
