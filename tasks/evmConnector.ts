import { getAddress } from "@zetachain/protocol-contracts";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import ZetaERC20Abi from "../abis/zetaRC20Abi.json";

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const polygonMumbaiConnectorAddr =
    "0xE66B7b71070747c43CBdBdF607f25Da8F073239e";

  const evmConnectorAbi = (
    await hre.artifacts.readArtifact(
      "contracts/EddyEvmConnector.sol:EddyEvmConnector"
    )
  ).abi;

  const evmConnector = new hre.ethers.Contract(
    polygonMumbaiConnectorAddr,
    evmConnectorAbi,
    signer
  );

  const zetaTokenERC20Addr = "0x0000c9ec4042283e8139c74f4c64bcd1e0b9b54f";

  const zetaTokenContract = new hre.ethers.Contract(
    zetaTokenERC20Addr,
    ZetaERC20Abi,
    signer
  );

  const allowanceInit = await zetaTokenContract.allowance(
    signer.address,
    polygonMumbaiConnectorAddr
  );

  console.log("Initial allowance", allowanceInit);

  const apprvTx = await zetaTokenContract.approve(
    polygonMumbaiConnectorAddr,
    hre.ethers.utils.parseEther("10000")
  );

  console.log(apprvTx.hash, "Hash of apprive");

  const allowanceFinal = await zetaTokenContract.allowance(
    signer.address,
    polygonMumbaiConnectorAddr
  );

  console.log("Final allowance", allowanceFinal);

  const destinationChainId = "7001";
  const destinationAddress = "0xebb1954e33aF4377D46B8B59C215A3E73572198a"; // Connector contract in zetachain
  const zetaAmountForTransfer = hre.ethers.utils.parseEther("7");
  const zetaSendTx = await evmConnector.sendMessage(
    destinationChainId,
    destinationAddress,
    zetaAmountForTransfer,
    {
      gasLimit: 2000000,
    }
  );

  console.log(`🚀 Successfully sent zeta in polygon to zetachain.
📜 Hash : ${zetaSendTx.hash}
`);
};

task("evmConnector", "evmConnector the contract", main);
