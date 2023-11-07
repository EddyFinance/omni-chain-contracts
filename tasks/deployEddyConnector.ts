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

  const zetaTokenZetachain = "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf";

  const systemContract = getAddress("systemContract", "zeta_testnet");

  console.log(systemContract, "systemContract ======>");

  const zetaConnectorAddr = "0x239e96c8f17C85c30100AC26F635Ea15f23E9c67";

  const factory = await hre.ethers.getContractFactory("EddyConnector");
  const connectorContract = await factory.deploy(
    zetaConnectorAddr,
    

  )

  console.log(`🚀 Successfully deployed contract on ZetaChain.
📜 Contract address: ${contract.address}
🌍 Explorer: https://athens3.explorer.zetachain.com/address/${contract.address}
`);
};

task("deploy", "Deploy the contract", main);
