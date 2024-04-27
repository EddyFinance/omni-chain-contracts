import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

import sushiAbi from "../abis/sushiRouterAbi.json";
import ERC20Abi from "../abis/usdt.json";

describe("Swap test", () => {
  let deployer: SignerWithAddress;
  let contract: any;
  let usdtContract: any;
  let provider: any;
  let signer: any;
  const sushiRouter = "0x0389879e0156033202C44BF784ac18fC02edeE4f";

  before(async () => {
    [signer] = await hre.ethers.getSigners();

    console.log("Signer ====>", signer.address);

    const coreDaoEddyRouterAbi = (
      await hre.artifacts.readArtifact(
        "contracts/CoreSwapEddy.sol:CoreSwapEddy"
      )
    ).abi;

    // get the transferNative contract
    contract = new ethers.Contract(
      "0x9E545E3C0baAB3E08CdfD552C960A1050f373042",
      coreDaoEddyRouterAbi,
      signer
    );

    // provider = new ethers.utils.
  });

  it("Swap CORE to USDT", async () => {
    console.log("Swapping ....");

    const slippage = await contract.slippage();
    const fees = await contract.platformFee();

    console.log("Slippage + fees", slippage, fees);

    const usdtContract = new hre.ethers.Contract(
      "0x900101d06A7426441Ae63e9AB3B9b0F63Be145F1",
      ERC20Abi,
      signer
    );

    const approvalTx = await usdtContract.approve(
      "0x9E545E3C0baAB3E08CdfD552C960A1050f373042",
      hre.ethers.utils.parseUnits("1000000", 18)
    );

    await approvalTx.wait();

    const initialBal = await usdtContract.balanceOf(signer.address);

    console.log(
      "Initails balance USDC",
      parseFloat(initialBal.toString()) / 1e6
    );

    const swapTx = await contract.swapEddyExactTokensForEth(
      "0x900101d06A7426441Ae63e9AB3B9b0F63Be145F1",
      "400000",
      "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
      "303485270837531459",
      signer.address,
      "0x02900101d06A7426441Ae63e9AB3B9b0F63Be145F101ffff0195DCC9e9BF80980375494346e00fc5aEF6883EF7000389879e0156033202C44BF784ac18fC02edeE4f0140375C92d9FAf44d2f9db9Bd9ba41a3317a2404f01ffff02009E545E3C0baAB3E08CdfD552C960A1050f373042",
      {
        gasLimit: 500_000,
      }
    );

    await swapTx.wait();

    console.log(swapTx, "Swapped transaction ======>");

    const finalBal = await usdtContract.balanceOf(signer.address);

    console.log("final balance USDC", parseFloat(finalBal.toString()) / 1e6);

    expect(finalBal).lessThan(initialBal);
  });

  it('Send ETH', async () => {
    const initialCoreBal = hre.ethers.provider.getBalance("0x9E545E3C0baAB3E08CdfD552C960A1050f373042");

    const tx = signer.sendTransaction

  })
});
