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

  const contractAddress = "0xFb93f3F8fEF341235455A6B8803f5f600940767B";

  const contract = new hre.ethers.Contract(
    contractAddress,
    eddyTransferNativeAbi,
    signer
  );

  const tx1 = await contract.updatePriceForAsset(
    "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
    2000
  );

  await tx1.wait();

  console.log(tx1.hash, tx1, "tx1 Transaction details");

  const tx2 = await contract.updatePriceForAsset(
    "0x65a45c57636f9BcCeD4fe193A602008578BcA90b",
    4000
  );

  await tx2.wait();

  console.log(tx2.hash, tx2, "tx2 Transaction details");

  const tx3 = await contract.updatePriceForAsset(
    "0x48f80608B672DC30DC7e3dbBd0343c5F02C738Eb",
    1
  );

  await tx3.wait();

  console.log(tx3.hash, tx3, "tx3 Transaction details");

  const tx4 = await contract.updatePriceForAsset(
    "0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891",
    305
  );

  await tx4.wait();

  console.log(tx4.hash, tx4, "tx4 Transaction details");

  const tx5 = await contract.updatePriceForAsset(
    "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf",
    1
  );

  await tx5.wait();

  console.log(tx5.hash, tx5, "tx5 Transaction details");
};

task("updatePricesEddyTransferNative", "Updating price for asset", main);
