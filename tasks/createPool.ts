import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import UniswapV2FactoryAbi from "../abis/uniswapV2Factory.json";
import {
  aZeta,
  EddyBNB,
  EddyBTC,
  EddyETH,
  EddyMATIC,
  ZRC20BNB,
} from "../utils/common";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_testnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const tokenA = ZRC20BNB;
  const tokenB = aZeta;

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  // Get uniswapV2 factory contract to create pool(Eddy deployed)
  const uniswapV2FactoryAddressZetachain =
    "0x100F5A01f26Eb4C4831CE5EFbCeE07F935BB247F";

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
