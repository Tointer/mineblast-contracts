/** @type import('hardhat/config').HardhatUserConfig */
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";

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
};

export default config;
