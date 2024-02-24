import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_mainnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();

  const imageUri = "ipfs://QmNe4LEHm8qCRjN5zGnepworwaEsBiCjFqf5fRFmdwLmRh";

  const eddyNftAbi = (
    await hre.artifacts.readArtifact("contracts/EddyNFTRewards.sol:EddyNFT")
  ).abi;

  const contractAddress = "0x278E636DB7a1BE6ABeD495F74BAd9e4cE9979966";

  const contract = new hre.ethers.Contract(contractAddress, eddyNftAbi, signer);

  //   const claimable = await contract.setClaimable(signer.address);

  //   console.log("Setting claim ======>");

  //   await claimable.wait();

  //   console.log("Hash of claim ======>", claimable.hash);

  const tx = await contract.mintNFT(imageUri);

  await tx.wait();

  console.log(tx.hash, "Mint hash ====>");
};

task("mintEddyNFT", "mintEddyNFT price for asset", main);
