import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture, mine } from "@nomicfoundation/hardhat-network-helpers";

describe("RainbowMix", function () {

  async function deployRainbowMixFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const rainbowMix = await ethers.getContractFactory("RainbowMix");
    const RainbowMix = await rainbowMix.deploy();

    return { RainbowMix, owner, addr1, addr2, addrs };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { RainbowMix, owner } = await loadFixture(deployRainbowMixFixture);
      expect(await RainbowMix.owner()).to.equal(await owner.getAddress());
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const { RainbowMix, owner } = await loadFixture(deployRainbowMixFixture);
      const ownerBalance = await RainbowMix.balanceOf(await owner.getAddress());
      expect(await RainbowMix.totalSupply()).to.equal(ownerBalance);
    });
  });


});
