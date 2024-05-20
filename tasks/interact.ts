import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import CurveAbi from "../abis/CurveAbi.json";
import Erc20Abi from "../abis/ERC20Abi.json";
import MailBoxAbi from "../abis/Mailbox.json";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);
  const ARB_MAILBOX = "0x26f4987f495eD2A52c772319986798371E4DA5f7";
  const CurveContract = new hre.ethers.Contract(
    ARB_MAILBOX,
    MailBoxAbi,
    signer
  );
  // console.log(CurveContract, "Curve contract ====>");

  // const addLiq = await CurveContract.add_liquidity(
  //   [0, hre.ethers.utils.parseUnits("130")],
  //   0
  // );

  const swapTx = await CurveContract.sendCrossChainMessage(
    "0xfc88a13a3fbdf8049d5b0e1f3bf5df52acc3c199",
    {
      gasLimit: 400_000,
      value: hre.ethers.utils.parseEther("0.0005"),
    }
  );

  // const swapTx = await CurveContract.withdrawBalance();

  // const swapTx = await CurveContract.setCounterContractInOtherChain(
  //   "0x26f4987f495eD2A52c772319986798371E4DA5f7"
  // );

  console.log(swapTx, "Add liq ====>");

  await swapTx.wait(1);
};

task("interact", "Interact with the contract", main);
