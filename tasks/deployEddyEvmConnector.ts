import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const zetaTokenZetachain = "0x0000c9ec4042283e8139c74f4c64bcd1e0b9b54f";

  const zetaConnectorAddr = "0x0000ecb8cdd25a18f12daa23f6422e07fbf8b9e1";

  const factory = await hre.ethers.getContractFactory("EddyConnector");
  const evmConnectorContract = await factory.deploy(
    zetaConnectorAddr,
    zetaTokenZetachain
  );

  await evmConnectorContract.deployed();

  console.log(`🚀 Successfully deployed contract on ZetaChain.
📜 Contract address: ${evmConnectorContract.address}
🌍 Explorer: https://athens3.explorer.zetachain.com/address/${evmConnectorContract.address}
`);
};

task("deployEddyEvmConnector", "deployEddyEvmConnector the contract", main);
