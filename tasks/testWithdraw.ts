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

  const eddyTransferNativeAbi = (
    await hre.artifacts.readArtifact(
      "contracts/EddyTransferNativeAssets.sol:EddyTransferNativeAssets"
    )
  ).abi;

  const contractAddress = "0x77a683cF5d800942Ed2Ac5a913Bc6aFd292a28Ba";

  const contract = new hre.ethers.Contract(
    contractAddress,
    eddyTransferNativeAbi,
    signer
  );

  const tx = await contract.withdrawToNativeChain(
    "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
    "10000000000000000",
    "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
    "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
    {
      gasLimit: 500000,
    }
  );

  await tx.wait();

  console.log(tx, "Transactions details");

};

task("testWithdraw", "testWithdraw task start...", main);
