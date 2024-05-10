import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import CurveAbi from "../abis/CurveAbi.json";
import Erc20Abi from "../abis/ERC20Abi.json";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const CurveContractAddr = "0xF2f6625AAAF95948C7aBD1F8e445DAa973ea6D0c";

  const EddyBtc = "0x5086C84B1B4e7a89dEbcbdDbd6176c4eE4cA5e4d";
  const EddyEth = "0x9cEC89Ce7686b1FE4Ea7cA708a38D835563dF6BF";

  const EddyEthContract = new hre.ethers.Contract(EddyEth, Erc20Abi, signer);
  const EddyBtcContract = new hre.ethers.Contract(EddyBtc, Erc20Abi, signer);

  // Give approval to curveRouter
  // const approvalEth = await EddyEthContract.approve(
  //   CurveContractAddr,
  //   hre.ethers.utils.parseUnits("100000", 18)
  // );

  // console.log(approvalEth, "Approval tx ======>");

  // await approvalEth.wait(1);

  // // Give approval to curveRouter
  // const approvalBtc = await EddyBtcContract.approve(
  //   CurveContractAddr,
  //   hre.ethers.utils.parseUnits("100000", 18)
  // );

  // console.log(approvalBtc, "Approval BTC tx ======>");

  // await approvalBtc.wait(1);

  const CurveContract = new hre.ethers.Contract(
    CurveContractAddr,
    CurveAbi,
    signer
  );
  // console.log(CurveContract, "Curve contract ====>");

  // const addLiq = await CurveContract.add_liquidity(
  //   [0, hre.ethers.utils.parseUnits("130")],
  //   0
  // );

  const swapTx = await CurveContract.remove_liquidity(
    hre.ethers.utils.parseUnits("149952989422747", 18),
    [0, 0]
  );

  console.log(swapTx, "Add liq ====>");

  await swapTx.wait(1);
};

task("interact", "Interact with the contract", main);
