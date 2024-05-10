import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "mode_mainnet") {
    throw new Error(
      '🚨 Please use the "mode_mainnet" network to deploy to Core.'
    );
  }

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  // const pythOnZeta = "0x2880aB155794e7179c9eE2e38200202908C17B43";

  // const systemContract = "0x91d18e54DAf4F677cB28167158d6dd21F6aB3921";

  const factory = await hre.ethers.getContractFactory("EddySwapRouterMode");
  const contract = await factory.deploy(10);
  await contract.deployed();

  console.log(`🚀 Successfully deployed contract on ZetaMainnet.
📜 Contract address: ${contract.address}
🌍 Explorer: https://scan.test.btcs.network/address/${contract.address}
`);
};

task("deploy", "Deploy the contract", main);
