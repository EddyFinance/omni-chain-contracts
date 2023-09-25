import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre from "hardhat";

import { EddyBNB, EddyETH } from "../utils/common";

describe("Mint EddyZEVMTOKEN to recipient", () => {
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

    console.log(JSON.stringify(tokenAbi), "Abi for the contract");

    // Initialize the contract

    TokenContract = new hre.ethers.Contract(EddyETH, tokenAbi, deployer);
  });

  it("Minting Wave tokens", async () => {
    console.log(TokenContract.mint, "token contract");

    // Mint Wave tokens to some user
    const userAddress = deployer.address;

    const initBal = await TokenContract.balanceOf(userAddress);
    console.log(initBal, "initial balance");

    const tx = await TokenContract.mint(
      userAddress,
      hre.ethers.utils.parseUnits("2000")
    );

    tx.wait();

    const hash = tx.hash;

    console.log(hash, "hash of mint =====>");

    const finalBal = await TokenContract.balanceOf(userAddress);

    console.log(finalBal, "final balance");

    expect(finalBal).greaterThan(initBal);
  });
});
