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
import "./tasks/deployNFT";
import "./tasks/mintEddyNFT";
import "./tasks/interact";
import "./tasks/interactNew";

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
    coredao_mainnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://rpc.coredao.org",
    },
    coredao_testnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://rpc.test.btcs.network",
    },
    kakarot_testnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://sepolia-rpc.kakarot.org",
    },
    localhost: {
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ],
      url: "http://127.0.0.1:8545/",
    },
    mode_mainnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://mainnet.mode.network",
    },
    polygon_mumbai: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://polygon-mumbai.g.alchemy.com/v2/CcIjayR-uykEFwpAt7sdfBM3swhISWXE",
    },
    zeta_mainnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://zetachain-evm.blockpi.network:443/v1/rpc/public",
    },
    zeta_testnet: {
      ...getHardhatConfigNetworks().zeta_testnet,
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
    },
    zklink_mainnet: {
      //@ts-ignore
      accounts: [process.env.PRIVATE_KEY],
      url: "https://rpc.zklink.io",
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.8.19",
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
      {
        version: "0.8.10",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 999999,
      },
    },
  },
  vyper: "0.3.10",
};

export default config;
