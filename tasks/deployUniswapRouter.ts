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
  console.log(`🔑 Using account: ${signer.address}\n`);

  const factory = await hre.ethers.getContractFactory("UniswapV2Router02");
  const contract = await factory.deploy(
    "0x100F5A01f26Eb4C4831CE5EFbCeE07F935BB247F",
    "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf"
  );
  await contract.deployed();

  console.log(`🚀 Successfully deployed UniswapV2 Router contract on ZetaChain.
📜 Contract address: ${contract.address}
🌍 Explorer: https://athens3.explorer.zetachain.com/address/${contract.address}
`);
};

task("deployUniswapRouter", "Deploy UniswapRouter", main);
