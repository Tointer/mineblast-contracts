// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MineblastSwapPair} from "../src/swap/MineblastSwapPair.sol";
import {MineblastSwapPairFactory} from "../src/swap/MineblastSwapPairFactory.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {MineblastLibrary} from "../src/swap/libraries/MineblastLibrary.sol";

contract MineblastSwapPairTest is Test {
    MineblastSwapPair public pair;
    MineblastSwapPairFactory public factory;
    ERC20Mock public token0;
    ERC20Mock public token1;

    address public user1 = address(0x1);

    function setUp() public {
        factory = new MineblastSwapPairFactory();
        token0 = new ERC20Mock("TOKEN0", "TKN0", 18);
        token1 = new ERC20Mock("TOKEN1", "TKN1", 18);
        pair = MineblastSwapPair(factory.createPair(address(token0), address(token1)));

        token0.mint(user1, 1e21);
        token1.mint(user1, 1e21);
    }

    function test_vwap() public {
        vm.startPrank(user1);
        token0.approve(address(pair), 1e21);
        token1.approve(address(pair), 1e21);
        pair.mint(user1, 1e19, 1e19);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 5);
        
        swapToken0(1e18); //buy token1

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1000);

        uint priceAfterSwap1 = getCurrentToken0Price();
        uint token0VWAPOutput = pair.getAveragePrice(1e18, 100);
        assertApproxEqRel(token0VWAPOutput, priceAfterSwap1, 0.01e18);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1000);

        swapToken0(1e18); //buy token1
        //assert same-block swap can't impact VWAP
        token0VWAPOutput = pair.getAveragePrice(1e18, 100);
        assertApproxEqRel(token0VWAPOutput, priceAfterSwap1, 0.01e18);
    }

    function getCurrentToken0Price() public view returns (uint) {
        (uint token0Reserve, uint token1Reserve,) = pair.getReserves();
        return token0Reserve*1e18/token1Reserve;
    }

    function swapToken0(uint amountIn) public {
        (uint token0Reserve, uint token1Reserve,) = pair.getReserves();
        uint amountOut = MineblastLibrary.getAmountOut(amountIn, token0Reserve, token1Reserve);

        pair.swap(amountIn, 0, 0, amountOut, msg.sender, ""); //buy token1
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
