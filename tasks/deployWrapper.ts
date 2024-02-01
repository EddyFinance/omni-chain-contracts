import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_mainnet") {
    throw new Error(
      '🚨 Please use the "zeta_mainnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const wrappedZetaAddr = "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf";
  const pythOnZeta = "0x2880aB155794e7179c9eE2e38200202908C17B43";

  const systemContract = "0x91d18e54DAf4F677cB28167158d6dd21F6aB3921";

  console.log(systemContract, "systemContract ======>");

  const factory = await hre.ethers.getContractFactory("WrapperEddyPoolsSwap");
  const contract = await factory.deploy(systemContract, pythOnZeta, 5, 20);

  await contract.deployed();

  console.log(`🚀 Successfully deployed contract on ZetaChain.
📜 Contract address: ${contract.address}
🌍 Explorer: https://athens3.explorer.zetachain.com/address/${contract.address}
`);
};

task("deployWrapper", "deployWrapper the contract", main);
