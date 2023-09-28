import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

import UniswapV2RouterABI from "../abis/uniswapV2Router.json";
import { EddyZEVMToken } from "../typechain-types";
import { aZeta, EddyBNB, EddyBTC, EddyETH } from "../utils/common";

describe("Swap test", () => {
  let uniswapV2Router: any;
  let deployer: SignerWithAddress;
  let tokenA = EddyBTC;
  let tokenB = EddyETH;
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

  it("Swapping", async () => {
    // function swapExactTokensForTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    const tokenAInputAmount = ethers.utils.parseUnits("0.05");
    const currentTimestampInSeconds = Math.floor(Date.now() / 1000);
    const deadline = currentTimestampInSeconds + 1000 * 60;

    const swapTx = await uniswapV2Router.swapExactTokensForTokens(
      tokenAInputAmount,
      0,
      [EddyBTC, aZeta, EddyBNB],
      deployer.address,
      deadline
    );

    swapTx.wait();

    const hash = swapTx.hash;

    console.log("Hash for swap:", hash);
  });
});
