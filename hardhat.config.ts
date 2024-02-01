import "./tasks/interact";
import "./tasks/deploy";
import "@nomicfoundation/hardhat-toolbox";
import "@zetachain/toolkit/tasks";
import "./tasks/deployToken";
import "./tasks/createPool";
import "./tasks/addLiquidity";
import "./tasks/deployUniswapFactory";
import "./tasks/deployUniswapRouter";
import "./tasks/deployEddyConnector";
import "./tasks/deployEddyEvmConnector";
import "./tasks/evmConnector";
import "./tasks/btcEncodedAddress";
import "./tasks/allowanceZRC20";
import "./tasks/updatePrice";
import "./tasks/deployEddyTransferNative";
import "./tasks/updatePricesEddyTransferNative";
import "./tasks/testWithdraw";
import "./tasks/deployWrapper";
import "./tasks/updatePricesWrapper";
import "./tasks/testTransferNative";
import "./tasks/convertWzetaToZeta";

import { getHardhatConfigNetworks } from "@zetachain/networks";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 400000,
  },
  networks: {
    hardhat: {
      chainId: 7001,
      forking: {
        url: "https://rpc.ankr.com/zetachain_evm_athens_testnet",
      },
    },
    ...getHardhatConfigNetworks(),
    polygon_mumbai: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://polygon-mumbai.g.alchemy.com/v2/CcIjayR-uykEFwpAt7sdfBM3swhISWXE",
    },
    zeta_mainnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://zetachain-evm.blockpi.network/v1/rpc/public",
    },
    zeta_testnet: {
      ...getHardhatConfigNetworks().zeta_testnet,
      url: "https://rpc.ankr.com/zetachain_evm_athens_testnet",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.8.5",
      },
      {
        version: "0.8.9",
      },
      {
        version: "0.5.16",
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.4.18",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 999999,
      },
    },
  },
};

export default config;
