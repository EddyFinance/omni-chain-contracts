import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import CoreSwapAbi from "../abis/CoreSwapEddy.json";
import { aZeta, EddyBNB, EddyBTC, EddyETH, EddyMATIC } from "../utils/common";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "coredao_mainnet") {
    throw new Error(
      '🚨 Please use the "coredao_mainnet" network to deploy to ZetaChain.'
    );
  }

  // const tokenA = "0x45334a5B0a01cE6C260f2B570EC941C680EA62c0"; // stZeta
  // const tokenB = aZeta; // WZeta TOKEN

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  //@ts-ignore
  // const eddyRouterAbi = new hre.artifacts.readArtifact(
  //   "contracts/CoreSwapEddy.sol:CoreSwapEddy"
  // ).abi;

  // Get uniswapV2 factory contract to create pool
  const eddyRouter = "0x9B93750C382867962a026eA0c241F6B685629F8d";

  const eddyRouterContract = new hre.ethers.Contract(
    eddyRouter,
    CoreSwapAbi,
    signer
  );

  const currentTimestampInSeconds = Math.floor(Date.now() / 1000);

  // Add 15 minutes in seconds (15 * 60 seconds per minute)
  const deadline = currentTimestampInSeconds + 1000 * 60;

  console.log(deadline, "Deadline#####");

  const swapTx = await eddyRouterContract.swapEddyExactETHForTokens(
    0,
    [
      "0x40375c92d9faf44d2f9db9bd9ba41a3317a2404f",
      "0x900101d06a7426441ae63e9ab3b9b0f63be145f1",
    ],
    {
      gasLimit: 200_000,
      value: hre.ethers.utils.parseEther("0.05"),
    }
  );

  await swapTx.wait();

  console.log(`🚀 Successfully addedliquidity to the pool.
  📜 Hash of the transaction: ${swapTx.hash}
  🌍 Explorer: https://explorer.zetachain.com/evm/tx/${swapTx.hash}
  `);
};

task("addLiquidity", "Adding liquidity to pools", main);
