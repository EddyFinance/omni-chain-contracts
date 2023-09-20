import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { EddyWave } from "../typechain-types";

describe("Mint EdyyWave to user", () => {
  let TokenContract: EddyWave;
  let deployer: SignerWithAddress;
  before(async () => {
    // Deploy the contract
    [deployer] = await ethers.getSigners();

    const factory = await ethers.getContractFactory("EddyWave");

    TokenContract = await factory.deploy();

    await TokenContract.deployed();

    console.log(`🚀 Successfully deployed WAVE token contract on ZetaChain.
    📜 Contract address: ${TokenContract.address}
    🌍 Explorer: https://athens3.explorer.zetachain.com/address/${TokenContract.address}
    `);
  });

  it("Minting Wave tokens", async () => {
    console.log(TokenContract.mint, "token contract");

    // Mint Wave tokens to some user
    const userAddress = "0x1f77e4ed1b40a976d7ef972fe2fabaa82ed690bf";

    const initBal = await TokenContract.balanceOf(userAddress);
    console.log(initBal, "initial balance");

    const tx = await TokenContract.mint(
      userAddress,
      ethers.utils.parseUnits("2000")
    );

    tx.wait();

    const hash = tx.hash;

    console.log(hash, "hash of mint =====>");

    const finalBal = await TokenContract.balanceOf(userAddress);

    console.log(finalBal, "final balance");

    expect(finalBal).greaterThan(initBal);
  });
});
