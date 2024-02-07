import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import '@typechain/hardhat';

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.23",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 1000000
          }
        },
      },
    ],
  },
  paths: {
    tests: "./test/hardhat-tests",
  },
  etherscan: {
    apiKey: {
      blast_sepolia: "blast_sepolia", // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: "blast_sepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
          browserURL: "https://testnet.blastscan.io"
        }
      }
    ]
  },
  networks: {
    blast_sepolia: {
      url: 'https://sepolia.blast.io',
      accounts: [process.env.PRIVATE_KEY || ''],
      chainId: 168587773,
    },
  },
};

export default config;
