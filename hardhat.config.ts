import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import '@typechain/hardhat';


const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.23",
      },
      {
        version: "0.5.16",
      },
    ],
  },
  paths: {
    tests: "./test/hardhat-tests",
  },
};

export default config;
