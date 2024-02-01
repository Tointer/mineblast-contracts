// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {MineblastSwapPair} from "../src/swap/MineblastSwapPair.sol";
import {MineblastSwapPairFactory} from "../src/swap/MineblastSwapPairFactory.sol";
import {MineblastFactory} from "../src/MineblastFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/MineblastVault.sol";
import "../src/swap/MineblastRouter.sol";

contract DeployScript is Script {
    function setUp() public {

    }

    function run() public {
        function run() public {
            uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");


            vm.startBroadcast(deployerPrivateKey);

            MineblastSwapPairFactory swapPairFactory = new MineblastSwapPairFactory();
            MineblastFactory mineblastFactory = new MineblastFactory(address(swapPairFactory));
            MineblastRouter router = new MineblastRouter(address(swapPairFactory), address(mineblastFactory));
            
            vm.stopBroadcast();

        }
    }
}
