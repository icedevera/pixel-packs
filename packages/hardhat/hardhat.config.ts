/**
 * @type import('hardhat/config').HardhatUserConfig
 */

import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";

require("dotenv").config();

const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL;
const POLYGON_MAINNET_RPC_URL = process.env.POLYGON_MAINNET_RPC_URL;
const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL;
const MNEMONIC = process.env.MNEMONIC;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

export const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // // If you want to do some forking, uncomment this
      // forking: {
      //   url: MAINNET_RPC_URL
      // }
    },
    localhost: {},
    rinkeby: {
      url: RINKEBY_RPC_URL,
      accounts: {
        mnemonic: MNEMONIC,
      },
      saveDeployments: true,
    },
    ganache: {
      url: "http://localhost:8545",
      accounts: {
        mnemonic: MNEMONIC,
      },
    },
    mumbai: {
      url: MUMBAI_RPC_URL,
      saveDeployments: true,
    },
    polygon: {
      url: POLYGON_MAINNET_RPC_URL,
      saveDeployments: true,
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    feeCollector: {
      default: 1,
    },
  },
  solidity: "0.8.9",
  mocha: {
    timeout: 100000,
  },
};

export default config;
