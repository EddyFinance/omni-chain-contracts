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

  // Get uniswapV2 factory contract to create pool
  const uniswapV2FactoryAddressZetachain = '0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c';
  

//   console.log(`🚀 Successfully deployed WAVE token contract on ZetaChain.
// 📜 Contract address: ${contract.address}
// 🌍 Explorer: https://athens3.explorer.zetachain.com/address/${contract.address}
// `);
};

task("createPool", "Creating pool for tokens", main);
