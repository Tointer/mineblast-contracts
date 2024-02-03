// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MineblastSwapPair} from "../src/swap/MineblastSwapPair.sol";
import {MineblastSwapPairFactory} from "../src/swap/MineblastSwapPairFactory.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {RebasingWETHMock} from "../src/mocks/RebasingWETHMock.sol";
import {MineblastLibrary} from "../src/swap/libraries/MineblastLibrary.sol";
import {MineblastRouter} from "../src/swap/MineblastRouter.sol";
import "./shared/BlastTest.sol";

contract MineblastRouterTest is BlastTest {
    MineblastSwapPair public pair;
    MineblastSwapPairFactory public factory;
    MineblastRouter public router;
    ERC20Mock public token1;

    address public user1 = address(0x1);

    function setUp() public {
        factory = new MineblastSwapPairFactory();
        token1 = new ERC20Mock("TOKEN1", "TKN1", 18);
        
        pair = MineblastSwapPair(factory.createPair(address(wethMock), address(token1)));
        router = new MineblastRouter(address(factory), payable(wethMock));

        token1.mint(user1, 1e21);
        wethMock.mint(user1, 1e21);

        vm.startPrank(user1);
        mintLiqudity(user1, 1e20, 2e20);
        vm.stopPrank();
    }

    function test_add_liqudity() public {
        uint wethIn = 5e18;
        uint expectedToken1Out = MineblastLibrary.quote(wethIn, 1e20, 2e20);
        console2.log("wethIn: ", wethIn);
        console2.log("expectedToken1Out: ", expectedToken1Out);

        vm.startPrank(user1);
        wethMock.approve(address(router), 1e21);
        token1.approve(address(router), 1e21);
        router.addLiquidity(address(wethMock), address(token1), wethIn, 
            expectedToken1Out, wethIn, expectedToken1Out, user1, block.timestamp + 1000);
        vm.stopPrank();
    }

    function mintLiqudity(address user, uint amount0, uint amount1) public {
        pair.sync();
        wethMock.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        pair.mint(user);
    }
}
