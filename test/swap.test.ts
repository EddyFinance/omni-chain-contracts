import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

import UniswapV2RouterABI from "../abis/uniswapV2Router.json";
import { EddyZEVMToken } from "../typechain-types";
import { aZeta, EddyBNB, EddyBTC, EddyETH } from "../utils/common";

describe("Swap test", () => {
  let deployer: SignerWithAddress;
  let contract: any;
  const wrappedZetaAddr = "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf";
  const usdcBSC = "0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0";
  before(async () => {
    const [signer] = await hre.ethers.getSigners();

    const eddyTransferNativeAbi = (
      await hre.artifacts.readArtifact(
        "contracts/EddyTransferNativeAssets.sol:EddyTransferNativeAssets"
      )
    ).abi;

    // get the transferNative contract
    contract = new ethers.Contract(
      "0x6081D792B67d466DBF81b53C0E57910537956374",
      eddyTransferNativeAbi,
      signer
    );
  });

  it("Bridge zeta to BSC USDC", async () => {
    const tx = await contract.transferZetaToConnectedChain(
      "0x00000000",
      wrappedZetaAddr,
      usdcBSC,
      {
        gasLimit: 500000,
        value: ethers.utils.parseEther("0.4"),
      }
    );

    await tx.wait();

    console.log(tx);
    
  });
});
