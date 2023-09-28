import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

import { EddyBNB, EddyBTC, EddyETH, EddyMATIC } from "../utils/common";

describe("EddyZevmToken tests", () => {
  let TokenContract: any;
  let deployer: SignerWithAddress;
  before(async () => {
    // Deploy the contract
    [deployer] = await hre.ethers.getSigners();

    const tokenAbi = (
      await hre.artifacts.readArtifact(
        "contracts/EddyZEVMToken.sol:EddyZEVMToken"
      )
    ).abi;

    TokenContract = new ethers.Contract(EddyMATIC, tokenAbi, deployer);
  });

  it("Minting 200 tokens", async () => {
    console.log(TokenContract.mint, "token contract");

    // Mint Wave tokens to some user
    const userAddress = deployer.address;

    const initBal = await TokenContract.balanceOf(userAddress);
    console.log(initBal, "initial balance");

    const tx = await TokenContract.mintOwner(
      hre.ethers.utils.parseUnits("200")
    );

    tx.wait();

    const hash = tx.hash;

    console.log(hash, "hash of mint =====>");

    const finalBal = await TokenContract.balanceOf(userAddress);

    console.log(finalBal, "final balance");

    // expect(finalBal).greaterThan(initBal);
  });
});
