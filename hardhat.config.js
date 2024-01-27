/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-foundry");

module.exports = {
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
