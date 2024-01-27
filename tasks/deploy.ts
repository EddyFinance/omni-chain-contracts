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

  const systemContract = getAddress("systemContract", "zeta_testnet");
  const pythOnZeta = "0x0708325268df9f66270f1401206434524814508b";

  console.log(systemContract, "systemContract ======>");

  const factory = await hre.ethers.getContractFactory("EddyCrossChain");
  const contract = await factory.deploy(systemContract, pythOnZeta, 5, 5);
  await contract.deployed();

  console.log(`🚀 Successfully deployed contract on ZetaChain.
📜 Contract address: ${contract.address}
🌍 Explorer: https://athens3.explorer.zetachain.com/address/${contract.address}
`);
};

task("deploy", "Deploy the contract", main);
