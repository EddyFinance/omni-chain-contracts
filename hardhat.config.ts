import "./tasks/interact";
import "./tasks/deploy";
import "@nomicfoundation/hardhat-toolbox";
import "@zetachain/toolkit/tasks";
import "./tasks/deployToken";
import "./tasks/createPool";
import "./tasks/addLiquidity";

import { getHardhatConfigNetworks } from "@zetachain/networks";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
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
    zeta_testnet: {
      ...getHardhatConfigNetworks().zeta_testnet,
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.8.9",
      },
    ],
  },
};

export default config;
