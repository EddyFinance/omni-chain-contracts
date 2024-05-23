import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import CurveFacAbi from "../abis/CurveFactory.json";
import Erc20Abi from "../abis/ERC20Abi.json";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const CurveFactoryAddr = "0x345a6C3b0D224Db7887EFEE68821Ddaa01473b57";

  const CurveFactory = new hre.ethers.Contract(
    CurveFactoryAddr,
    CurveFacAbi,
    signer
  );

  // Create new pool
  const tx = await CurveFactory.deploy_plain_pool(
    "Curve Zeta/stZeta StableSwap",
    "stzCRV",
    [
      "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf",
      "0x45334a5B0a01cE6C260f2B570EC941C680EA62c0",
    ],
    200, // _A
    4000000, // _fee,
    20000000000,
    866,
    0,
    [0, 0],
    ["0x00000000", "0x00000000"],
    [
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
    ],
    {
      gasLimit: 400_000,
    }
  );

  await tx.wait();

  console.log(tx, "Tx details ====>");
  
};

task("interactNew", "Interact with the contract", main);
