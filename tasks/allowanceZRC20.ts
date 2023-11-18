import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import Abi from "../abis/zetaRC20Abi.json";
const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name !== "zeta_testnet") {
    throw new Error(
      '🚨 Please use the "zeta_testnet" network to deploy to ZetaChain.'
    );
  }

  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const ZRC20Token = new hre.ethers.Contract(
    "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
    Abi,
    signer
  );

  const initAll = await ZRC20Token.allowance(
    signer.address,
    "0x1638de1169092fe692A6C6fd027256Bb699D4dB4"
  );

  console.log(initAll, "initAll =====>");

  const tx = await ZRC20Token.approve(
    "0x1638de1169092fe692A6C6fd027256Bb699D4dB4",
    hre.ethers.utils.parseUnits("100000000000000")
  );

  console.log(tx.hash, "hash");

  const finalAll = await ZRC20Token.allowance(
    signer.address,
    "0x1638de1169092fe692A6C6fd027256Bb699D4dB4"
  );

  console.log(finalAll, "finalAll =======>");
};

task("allowanceZRC20", "allowanceZRC20 the contract", main);
