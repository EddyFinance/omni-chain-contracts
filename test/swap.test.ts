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
      "0x4Bd2678602694F392361623A87Cb8e771B03BF22",
      eddyTransferNativeAbi,
      signer
    );

    const abiUSDTEth = [
      "function approve(address spender,uint256 amount) external",
    ];

    const USDTContract = new ethers.Contract(
      "0x7c8dda80bbbe1254a7aacf3219ebe1481c6e01d7",
      abiUSDTEth,
      signer
    );

    const approveTx = await USDTContract.approve(
      "0x4Bd2678602694F392361623A87Cb8e771B03BF22",
      ethers.utils.parseUnits("2000000000000000")
    );

    await approveTx.wait();

    console.log(approveTx, "Approval tx");
    

  });
  it("Bridge USDT.ETH to USDT on BSC", async () => {
    const tx = await contract.withdrawToNativeChain(
      "0x00000000",
      "1230000",
      "0x7c8dda80bbbe1254a7aacf3219ebe1481c6e01d7",
      "0x91d4f0d54090df2d81e834c3c8ce71c6c865e79f",
      {
        gasLimit: 500000,
      }
    );

    console.log(tx, "transaction ======>");
  });

  // it("Bridge zeta to BSC USDC", async () => {
  //   const tx = await contract.transferZetaToConnectedChain(
  //     "0x00000000",
  //     wrappedZetaAddr,
  //     usdcBSC,
  //     {
  //       gasLimit: 500000,
  //       value: ethers.utils.parseEther("0.4"),
  //     }
  //   );

  //   await tx.wait();

  //   console.log(tx);
  // });
});
