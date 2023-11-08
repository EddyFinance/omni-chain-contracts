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
  const eddyConnector = "0xebb1954e33aF4377D46B8B59C215A3E73572198a";

  const systemContract = getAddress("systemContract", "zeta_testnet");

  console.log(systemContract, "systemContract ======>");

  const factory = await hre.ethers.getContractFactory("EddyPool");
  const poolContract = await factory.deploy(
    systemContract,
    zetaTokenZetachain,
    eddyConnector
  );

  await poolContract.deployed();

  console.log(`🚀 Successfully deployed contract on ZetaChain.
📜 Contract address: ${poolContract.address}
🌍 Explorer: https://athens3.explorer.zetachain.com/address/${poolContract.address}
`);

  const poolContractAddr = poolContract.address;

  const connectorAbi = (
    await hre.artifacts.readArtifact("contracts/EddyPool.sol:EddyPool")
  ).abi;

  const connectorContract = new hre.ethers.Contract(
    eddyConnector,
    connectorAbi,
    signer
  );

  // Set the connector contract in pool
  const tx = await connectorContract.setPoolContract(poolContractAddr);

  tx.wait();

  console.log(tx.hash, "Hash of setting pool in zetachain");

  const eddyPool = await connectorContract._eddyPool();

  console.log(eddyPool, "Eddy pool contract address in connector");
};

task("deployEddyPool", "deployEddyPool the contract", main);
