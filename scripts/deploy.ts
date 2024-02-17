import { ethers } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';

async function main(): Promise<void> {
  const RainbowMixFactory: ContractFactory = await ethers.getContractFactory(
    'RainbowMix',
  );
  const RainbowMix: Contract = await RainbowMixFactory.deploy();
  await RainbowMix.deployed();
  console.log('RainbowMix deployed to: ', RainbowMix.address);
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
