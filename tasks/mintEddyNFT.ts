import { getAddress } from '@zetachain/protocol-contracts';
import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== 'zeta_testnet') {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();

  const imageUri = 'ipfs://QmUXcZdbhJD6J4GYPBF9zkuYVA5oMfSqK5e5RPYMmeE5VL';
  const signature =
    '0x66d7fdc84e7e24fd8edf324d73d35bd4210efec85c2af2f21da5df2c9f74eaab51d0bf2aa32a84f6972a12d6d862a0a330e786a9f03b3ccdf0fb9efaacd516d91c';
  const eddyNftAbi = (
    await hre.artifacts.readArtifact('contracts/EddyNFTRewards.sol:EddyNFT')
  ).abi;

  const contractAddress = '0x9f40ea3A30Fe99E88adff191574e68453394293A';

  const contract = new hre.ethers.Contract(contractAddress, eddyNftAbi, signer);

  const tx = await contract.mintNFT(
    '0xD4B0999f465C7b4F15eB6f709b4793553ab6b99C',
    imageUri,
    signature
  );

  await tx.wait();

  console.log(tx.hash, 'Mint hash ====>');
};

task('mintEddyNFT', 'mintEddyNFT price for asset', main);
