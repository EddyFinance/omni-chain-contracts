import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import UniswapV2FactoryAbi from "../abis/uniswapV2Factory.json";
import { EddyBNB, EddyBTC, EddyETH, EddyMATIC } from "../utils/common";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_testnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const tokenA = EddyBTC;
  const tokenB = EddyETH;

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  // Get uniswapV2 factory contract to create pool
  const uniswapV2FactoryAddressZetachain =
    "0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c";

  const uniswapV2FactoryContract = new hre.ethers.Contract(
    uniswapV2FactoryAddressZetachain,
    UniswapV2FactoryAbi,
    signer
  );

  const tx = await uniswapV2FactoryContract.createPair(tokenA, tokenB);

  tx.wait();

  const hash = tx.hash;

  console.log(`🚀 Successfully created pool.
  📜 Hash of the transaction: ${hash}
  🌍 Explorer: https://explorer.zetachain.com/evm/tx/${hash}
  `);
};

task("createPool", "Creating pool for tokens", main);
