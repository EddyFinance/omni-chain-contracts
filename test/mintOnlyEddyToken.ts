import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre from "hardhat";

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

    TokenContract = new hre.ethers.Contract(
      "0x2A8E1F83129d349197aE5Edd29Dbe930292079aD",
      tokenAbi,
      deployer
    );
  });

  it("Minting Wave tokens", async () => {
    console.log(TokenContract.mint, "token contract");

    // Mint Wave tokens to some user
    const userAddress = "0x1f77e4ed1b40a976d7ef972fe2fabaa82ed690bf";

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
