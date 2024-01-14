import { getAddress } from "@zetachain/protocol-contracts";
import hre from "hardhat";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_testnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();

  const eddyCrossChainContractAbi = (
    await hre.artifacts.readArtifact(
      "contracts/EddyCrossChain.sol:EddyCrossChain"
    )
  ).abi;

  const contractAddress = "0xDa11C5662C7F6CAff22f9B0A60a08584C1066520";

  const contract = new hre.ethers.Contract(
    contractAddress,
    eddyCrossChainContractAbi,
    signer
  );

  const tx1 = await contract.updatePriceForAsset(
    "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
    2000
  );

  await tx1.wait();

  const tx2 = await contract.updatePriceForAsset(
    "0x65a45c57636f9BcCeD4fe193A602008578BcA90b",
    4000
  );

  await tx2.wait();

  const tx3 = await contract.updatePriceForAsset(
    "0x48f80608B672DC30DC7e3dbBd0343c5F02C738Eb",
    1
  );

  await tx3.wait();

  const tx4 = await contract.updatePriceForAsset(
    "0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891",
    305
  );

  await tx4.wait();

  console.log(tx4.hash, tx4, "tx4 Transaction details");
  console.log(tx1.hash, tx1, "tx1 Transaction details");
  console.log(tx2.hash, tx2, "tx2 Transaction details");
  console.log(tx3.hash, tx3, "tx3 Transaction details");
};

task("updatePrice", "Updating price for asset", main);