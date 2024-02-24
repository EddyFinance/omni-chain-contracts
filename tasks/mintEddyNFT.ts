import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_testnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();

  const imageUri = "ipfs://QmNe4LEHm8qCRjN5zGnepworwaEsBiCjFqf5fRFmdwLmRh";

  const eddyNftAbi = (
    await hre.artifacts.readArtifact("contracts/EddyNFTRewards.sol:EddyNFT")
  ).abi;

  const claimableAddresses = [
    "0x1aBeA91c444E43cBf645dB61F4DC09200F0E25b0",
    "0x06Cf18ec8DaDA3E6b86c38DE2c5536811Cd9594C",
  ];

  const contractAddress = "0x9B93750C382867962a026eA0c241F6B685629F8d";

  const contract = new hre.ethers.Contract(contractAddress, eddyNftAbi, signer);

  const claimable = await contract.setClaimable(claimableAddresses);

  console.log("Setting claim ======>");

  await claimable.wait();

  console.log("Hash of claim ======>", claimable.hash);

  const tx = await contract.mintNFT(imageUri);

  await tx.wait();

  console.log(tx.hash, "Mint hash ====>");
};

task("mintEddyNFT", "mintEddyNFT price for asset", main);
