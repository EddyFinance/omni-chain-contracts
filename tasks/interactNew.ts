import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import stETHZircuit from "../abis/stETHZircuit.json";
import CurveZircuitAbi from "../abis/ZircuitStableSwap.json";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const stableSwapZircuit = "0xCb0ca072EFb267F17289574Bf563e8dF05c7Ffe3";

  const stETH = "0x9B93750C382867962a026eA0c241F6B685629F8d";

  const stETHTOkenContract = new hre.ethers.Contract(
    stETH,
    stETHZircuit,
    signer
  );

  const tx = await stETHTOkenContract.modifyWaitTime(
    100
  );

  await tx.wait();

  console.log(tx, "Transfer tx ===>");
  

  // const allowance = await stETHTOkenContract.allowance(
  //   signer.address,
  //   stableSwapZircuit
  // );

  // Approve

  // const approveTx = await stETHTOkenContract.approve(
  //   stableSwapZircuit,
  //   hre.ethers.utils.parseUnits("1000000", 18)
  // );

  // await approveTx.wait();

  // console.log(approveTx, "Approve tx");

  // const ContractStableSwap = new hre.ethers.Contract(
  //   stableSwapZircuit,
  //   [
  //     {
  //       inputs: [
  //         {
  //           name: "i",
  //           type: "uint256",
  //         },
  //       ],
  //       name: "balances",
  //       outputs: [
  //         {
  //           name: "",
  //           type: "uint256",
  //         },
  //       ],
  //       stateMutability: "view",
  //       type: "function",
  //     },
  //     {
  //       inputs: [
  //         {
  //           name: "amounts",
  //           type: "uint256[2]",
  //         },
  //         {
  //           name: "min_mint_amount",
  //           type: "uint256",
  //         },
  //       ],
  //       name: "add_liquidity",
  //       outputs: [
  //         {
  //           name: "",
  //           type: "uint256",
  //         },
  //       ],
  //       stateMutability: "payable",
  //       type: "function",
  //     },
  //   ],
  //   signer
  // );

  // const resrves = await ContractStableSwap.balances(0);

  // console.log(resrves, "resrves ===>");

  // const tx = await ContractStableSwap.add_liquidity(
  //   [
  //     hre.ethers.utils.parseEther("0.001"),
  //     hre.ethers.utils.parseUnits("0.001", 18),
  //   ],
  //   0,
  //   {
  //     gasLimit: 500_000,
  //     value: hre.ethers.utils.parseEther("0.001"),
  //   }
  // );

  // await tx.wait();

  // console.log(tx, "Add liq tx");
};

task("interactNew", "Interact with the contract", main);
