import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import UniswapV2RouterAbi from "../abis/uniswapV2Router.json";
import { aZeta, EddyBNB, EddyBTC, EddyETH, EddyMATIC } from "../utils/common";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_mainnet") {
    throw new Error(
      '🚨 Please use the "zeta_mainnet" network to deploy to ZetaChain.'
    );
  }

  const tokenA = "0x45334a5B0a01cE6C260f2B570EC941C680EA62c0"; // stZeta
  const tokenB = aZeta; // WZeta TOKEN

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

  // const tokenAbi = (
  //   await hre.artifacts.readArtifact(
  //     "contracts/EddyZEVMToken.sol:EddyZEVMToken"
  //   )
  // ).abi;

  const tokenAbi = [
    {
      inputs: [
        {
          internalType: "address",
          name: "spender",
          type: "address",
        },
        {
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
      ],
      name: "approve",
      outputs: [
        {
          internalType: "bool",
          name: "",
          type: "bool",
        },
      ],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [
        {
          internalType: "address",
          name: "owner",
          type: "address",
        },
        {
          internalType: "address",
          name: "spender",
          type: "address",
        },
      ],
      name: "allowance",
      outputs: [
        {
          internalType: "uint256",
          name: "",
          type: "uint256",
        },
      ],
      stateMutability: "view",
      type: "function",
    },
  ];

  const tokenAContract = new hre.ethers.Contract(tokenA, tokenAbi, signer); // stZeta
  // const tokenBContract = new hre.ethers.Contract(tokenB, tokenAbi, signer); // Wzeta

  // Checking allowance
  const allowanceA = await tokenAContract.allowance(
    signer.address,
    uniswapV2RouterZetachainAddr
  );
  // const allowanceB = await tokenBContract.allowance(
  //   signer.address,
  //   uniswapV2RouterZetachainAddr
  // );

  console.log(`Allowances: tokenA ${allowanceA} `);

  console.log("Getting allowances...");

  // const txAllowanceA = await tokenAContract.approve(
  //   uniswapV2RouterZetachainAddr,
  //   hre.ethers.utils.parseUnits("10000000000", 18)
  // );
  // await txAllowanceA.wait();

  // const hashAllowanceA = txAllowanceA.hash;

  // console.log("Hash for tokenA allowance", hashAllowanceA);

  // const txAllowanceB = await tokenBContract.approve(
  //   uniswapV2RouterZetachainAddr,
  //   hre.ethers.utils.parseUnits("10000000000")
  // );

  // txAllowanceB.wait();

  // const hashAllowanceB = txAllowanceA.hash;

  // console.log("Hash for tokenB allowance", hashAllowanceB);

  const currentTimestampInSeconds = Math.floor(Date.now() / 1000);

  // Add 15 minutes in seconds (15 * 60 seconds per minute)
  const deadline = currentTimestampInSeconds + 1000 * 60;

  console.log(deadline, "Deadline#####");
  

  // console.log(
  //   {
  //     amountA: hre.ethers.utils.parseUnits("1"),
  //     amountB: hre.ethers.utils.parseUnits("1"),
  //     deadline,
  //     minA: 0,
  //     minB: 0,
  //     to: signer.address,
  //     tokenA,
  //     tokenB,
  //   },
  //   "Params ====>"
  // );

  const tx = await uniswapV2RouterContract.addLiquidityETH(
    tokenA,
    hre.ethers.utils.parseUnits("4.9569"), // amount of stZeta
    0, // amount stZeta minimum
    0, // Amount zeta minimum
    signer.address,
    "1708463162",
    {
      gasLimit: 600000,
      value: hre.ethers.utils.parseEther("5"),
    }
  );

  await tx.wait();

  const hash = tx.hash;

  console.log(tx, "transaction details");

  console.log(`🚀 Successfully addedliquidity to the pool.
  📜 Hash of the transaction: ${hash}
  🌍 Explorer: https://explorer.zetachain.com/evm/tx/${hash}
  `);
};

task("addLiquidity", "Adding liquidity to pools", main);
