import { getAddress } from "@zetachain/protocol-contracts";
import hre from "hardhat";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_mainnet") {
    throw new Error(
      '🚨 Please use the "zeta_mainnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();

  const eddyCrossChainContractAbi = (
    await hre.artifacts.readArtifact(
      "contracts/EddyCrossChain.sol:EddyCrossChain"
    )
  ).abi;

  const contractAddress = "0xBdED16d4275Af02b5F4122208ec27C4Eef78509c";

  const contract = new hre.ethers.Contract(
    contractAddress,
    eddyCrossChainContractAbi,
    signer
  );

  const tx = await contract.platformFee();
  // const tx = await contract.updateSlippage(10);

  // await tx.wait();

  console.log(tx, "TX =====>");

  // const tx1 = await contract.updateAddressToTokenId(
  //   "0xb70656181007f487e392bf0d92e55358e9f0da5da6531c7c4ce7828aa11277fe",
  //   "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf"
  // );

  // await tx1.wait();

  // console.log(tx1.hash, tx1, "tx1 Transaction details");

  // // BTC tokenId
  // const tx2 = await contract.updateAddressToTokenId(
  //   "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
  //   "0x65a45c57636f9BcCeD4fe193A602008578BcA90b"
  // );

  // await tx2.wait();

  // console.log(tx2.hash, tx2, "tx2 Transaction details");

  // // ETH tokenId
  // const tx3 = await contract.updateAddressToTokenId(
  //   "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
  //   "0x13a0c5930c028511dc02665e7285134b6d11a5f4"
  // );

  // await tx3.wait();

  // console.log(tx3.hash, tx3, "tx2 Transaction details");

  // // BNB tokenId
  // const tx4 = await contract.updateAddressToTokenId(
  //   "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f",
  //   "0xd97b1de3619ed2c6beb3860147e30ca8a7dc9891"
  // );

  // await tx4.wait();

  // console.log(tx4.hash, tx4, "tx4 Transaction details");

  // // MATIC tokenId
  // const tx5 = await contract.updateAddressToTokenId(
  //   "0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52",
  //   "0x48f80608B672DC30DC7e3dbBd0343c5F02C738Eb"
  // );

  // await tx5.wait();

  // console.log(tx5.hash, tx5, "tx5 Transaction details");
};

task("updatePrice", "Updating price for asset", main);
