import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre from "hardhat";

import UniswapV2RouterABI from "../abis/uniswapV2Router.json";
import { EddyZEVMToken } from "../typechain-types";
import { aZeta, EddyBNB, EddyBTC, EddyETH, EddyMATIC } from "../utils/common";

describe("Swap test", () => {
  let uniswapV2Router: any;
  let deployer: SignerWithAddress;
  let tokenA = EddyMATIC;
  let tokenB = aZeta;
  let uniswapV2RouterZetachainAddr: string;
  let tokenAContract: any;
  let tokenBContract: any;
  before(async () => {
    // Deploy the contract
    [deployer] = await hre.ethers.getSigners();

    uniswapV2RouterZetachainAddr = "0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe";

    // const tokenAbi = (
    //   await hre.artifacts.readArtifact(
    //     "contracts/EddyZEVMToken.sol:EddyZEVMToken"
    //   )
    // ).abi;
    uniswapV2Router = new hre.ethers.Contract(
      uniswapV2RouterZetachainAddr,
      UniswapV2RouterABI,
      deployer
    );

    const tokenAbi = (
      await hre.artifacts.readArtifact(
        "contracts/EddyZEVMToken.sol:EddyZEVMToken"
      )
    ).abi;

    tokenAContract = new hre.ethers.Contract(tokenA, tokenAbi, deployer);
    tokenBContract = new hre.ethers.Contract(tokenB, tokenAbi, deployer);
  });

  it("Checking allowance", async () => {
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

    // Checking allowance
    const allowanceA = await tokenAContract.allowance(
      deployer.address,
      uniswapV2RouterZetachainAddr
    );
    const allowanceANum = parseFloat(allowanceA.toString());

    const allowanceB = await tokenBContract.allowance(
      deployer.address,
      uniswapV2RouterZetachainAddr
    );

    const allowanceBNum = parseFloat(allowanceB.toString());

    console.log(`Allowances: tokenA ${allowanceA} and tokenB ${allowanceB}`);

    expect(allowanceANum).greaterThan(0);
    expect(allowanceBNum).greaterThan(0);
  });

  it("Adding liquidity", async () => {
    const currentTimestampInSeconds = Math.floor(Date.now() / 1000);
    const deadline = currentTimestampInSeconds + 1000 * 60;
    // const tx = await uniswapV2Router.addLiquidity(
    //   tokenA,
    //   tokenB,
    //   hre.ethers.utils.parseUnits("50"),
    //   hre.ethers.utils.parseUnits("50"),
    //   0,
    //   0,
    //   deployer.address,
    //   deadline,
    //   {
    //     gasLimit: 20000000,
    //   }
    // );

    const tx = await uniswapV2Router.addLiquidityETH(
      tokenA,
      hre.ethers.utils.parseUnits("50"),
      0,
      0,
      deployer.address,
      deadline,
      {
        gasLimit: 20000000,
        value: hre.ethers.utils.parseUnits("50"),
      }
    );

    console.log(tx, "Transaction details");

    tx.wait();

    const hash = tx.hash;

    console.log(hash, "Hash of the transaction...");
  });
});
