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

  const eddyTransferNativeAbi = (
    await hre.artifacts.readArtifact(
      "contracts/EddyTransferNativeAssets.sol:EddyTransferNativeAssets"
    )
  ).abi;

  const contractAddress = "0xd35363C0e856d1dC757BECCae469374A02D8384D";

  const contract = new hre.ethers.Contract(
    contractAddress,
    eddyTransferNativeAbi,
    signer
  );

  const resp = await contract.systemContract(
    "0xd97b1de3619ed2c6beb3860147e30ca8a7dc9891"
  );

  console.log(resp, "Transaciton zeta update price");

};

task("testTransferNative", "testTransferNative price for asset", main);
