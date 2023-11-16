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
import "./tasks/deployEddyPool";
import "./tasks/deployEddyEvmConnector";
import "./tasks/evmConnector";
import "./tasks/btcEncodedAddress";
import "./tasks/allowanceZRC20";

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
        url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      },
    },
    ...getHardhatConfigNetworks(),
    polygon_mumbai: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://polygon-mumbai.g.alchemy.com/v2/CcIjayR-uykEFwpAt7sdfBM3swhISWXE",
    },
    zeta_testnet: {
      ...getHardhatConfigNetworks().zeta_testnet,
      url: "https://rpc-archive.athens.zetachain.com:8545",
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
