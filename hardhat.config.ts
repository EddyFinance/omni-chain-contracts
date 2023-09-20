import "./tasks/interact";
import "./tasks/deploy";
import "@nomicfoundation/hardhat-toolbox";
import "@zetachain/toolkit/tasks";
import "./tasks/deployToken";
import "./tasks/createPool";

import { getHardhatConfigNetworks } from "@zetachain/networks";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  networks: {
    ...getHardhatConfigNetworks(),
    zeta_testnet: {
      ...getHardhatConfigNetworks().zeta_testnet,
      url: "https://jsonrpc-t.zeta.nodestake.top/",
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
