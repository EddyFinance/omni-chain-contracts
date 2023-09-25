import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import UniswapV2RouterAbi from "../abis/uniswapV2Router.json";
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
  const uniswapV2RouterZetachainAddr =
    "0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe";

  const uniswapV2RouterContract = new hre.ethers.Contract(
    uniswapV2RouterZetachainAddr,
    UniswapV2RouterAbi,
    signer
  );

  // Give allowance to router contract for tokenA/tokenB

  const tokenAbi = (
    await hre.artifacts.readArtifact(
      "contracts/EddyZEVMToken.sol:EddyZEVMToken"
    )
  ).abi;

  const tokenAContract = new hre.ethers.Contract(tokenA, tokenAbi, signer);
  const tokenBContract = new hre.ethers.Contract(tokenB, tokenAbi, signer);

  // Checking allowance
  const allowanceA = await tokenAContract.allowance(
    signer.address,
    uniswapV2RouterZetachainAddr
  );
  const allowanceB = await tokenBContract.allowance(
    signer.address,
    uniswapV2RouterZetachainAddr
  );

  console.log(`Allowances: tokenA ${allowanceA} and tokenB ${allowanceB}`);

  console.log("Getting allowances...");

  const txAllowanceA = await tokenAContract.approve(
    uniswapV2RouterZetachainAddr,
    hre.ethers.utils.parseUnits("10000000000")
  );
  txAllowanceA.wait();

  const hashAllowanceA = txAllowanceA.hash;

  console.log("Hash for tokenA allowance", hashAllowanceA);

  const txAllowanceB = await tokenBContract.approve(
    uniswapV2RouterZetachainAddr,
    hre.ethers.utils.parseUnits("10000000000")
  );

  txAllowanceB.wait();

  const hashAllowanceB = txAllowanceA.hash;

  console.log("Hash for tokenB allowance", hashAllowanceB);

  const currentTimestampInSeconds = Math.floor(Date.now() / 1000);

  // Add 15 minutes in seconds (15 * 60 seconds per minute)
  const deadline = currentTimestampInSeconds + 1000 * 60;

  console.log(
    {
      amountA: hre.ethers.utils.parseUnits("1"),
      amountB: hre.ethers.utils.parseUnits("1"),
      deadline,
      minA: 0,
      minB: 0,
      to: signer.address,
      tokenA,
      tokenB,
    },
    "Params ====>"
  );

  const tx = await uniswapV2RouterContract.addLiquidity(
    tokenA,
    tokenB,
    hre.ethers.utils.parseUnits("10"),
    hre.ethers.utils.parseUnits("10"),
    1,
    1,
    signer.address,
    deadline,
    {
      gasLimit: 20000000,
    }
  );

  tx.wait();

  const hash = tx.hash;

  console.log(tx, "transaction details");

  console.log(`🚀 Successfully addedliquidity to the pool.
  📜 Hash of the transaction: ${hash}
  🌍 Explorer: https://explorer.zetachain.com/evm/tx/${hash}
  `);
};

task("addLiquidity", "Adding liquidity to pools", main);
