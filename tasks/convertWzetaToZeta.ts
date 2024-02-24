import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import WzetaAbi from "../abis/WZETA.json";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_mainnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();

  //   const eddyTransferNativeAbi = (
  //     await hre.artifacts.readArtifact(
  //       "contracts/EddyTransferNativeAssets.sol:EddyTransferNativeAssets"
  //     )
  //   ).abi;

  const wzetaAmt = hre.ethers.utils.parseEther("1000");

  const contractAddress = "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf";

  const WzetaContract = new hre.ethers.Contract(
    contractAddress,
    WzetaAbi,
    signer
  );

  const tx = await WzetaContract.withdraw(wzetaAmt);

  await tx.wait();

  console.log(tx, "Transaciton zeta update price");
};

task("convertWzetaToZeta", "convertWzeta price for asset", main);
