import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

import UniswapV2RouterABI from "../abis/uniswapV2Router.json";
import { aZeta, EddyBNB, EddyBTC, EddyETH, EddyMATIC } from "../utils/common";

describe("Quote test", () => {
  let TokenContract: any;
  let deployer: SignerWithAddress;
  let uniswapV2ZetaFactoryAddr = "0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c";
  let uniswapV2RouterZetachainAddr =
    "0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe";
  let uniswapV2Router: any;

  before(async () => {
    // Deploy the contract
    [deployer] = await hre.ethers.getSigners();

    const tokenAbi = (
      await hre.artifacts.readArtifact(
        "contracts/EddyZEVMToken.sol:EddyZEVMToken"
      )
    ).abi;

    TokenContract = new ethers.Contract(EddyMATIC, tokenAbi, deployer);

    uniswapV2Router = new hre.ethers.Contract(
      uniswapV2RouterZetachainAddr,
      UniswapV2RouterABI,
      deployer
    );
  });

  it("Get quote for amountIn", async () => {
    const amountIn = ethers.utils.parseUnits("0.5");

    const path = [EddyBNB, aZeta, EddyETH];

    const outputAmount = await uniswapV2Router.getAmountsOut(amountIn, path);

    console.log("Output amount:", outputAmount);

    expect(outputAmount[path.length - 1]).gte(0);
  });
});
