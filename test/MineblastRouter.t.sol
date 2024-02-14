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
        vm.deal(user1, 1e21);
        vm.startPrank(user1);
        wethMock.deposit{value: 1e21}();
        vm.stopPrank();

        vm.startPrank(user1);
        mintLiqudity(user1, 1e20, 2e20);
        vm.stopPrank();
    }

    function test_add_burn_liqudity() public {
        uint wethIn = 5e18;
        uint expectedToken1Out = MineblastLibrary.quote(wethIn, 1e20, 2e20);

        uint userTokenBalanceBefore = token1.balanceOf(user1);
        uint userWethBalanceBefore = wethMock.balanceOf(user1);

        vm.startPrank(user1);
        wethMock.approve(address(router), 1e21);
        token1.approve(address(router), 1e21);
        router.addLiquidity(address(wethMock), address(token1), wethIn, 
            expectedToken1Out, wethIn, expectedToken1Out, user1, block.timestamp + 1000);

        uint liquidity = pair.balanceOf(user1);
        pair.approve(address(router), liquidity);
        router.removeLiquidity(address(wethMock), address(token1), liquidity, 0, 0, user1, block.timestamp + 1000);
        vm.stopPrank();

        assertEq(token1.balanceOf(user1), userTokenBalanceBefore);
        assertEq(wethMock.balanceOf(user1), userWethBalanceBefore);
    }

    function test_add_liqudity_eth() public {
        uint ethIn = 5e18;
        uint expectedToken1Out = MineblastLibrary.quote(ethIn, 1e20, 2e20);
        vm.deal(user1, ethIn);

        vm.startPrank(user1);
        token1.approve(address(router), 1e21);
        router.addLiquidityETH{value: ethIn}(address(token1), expectedToken1Out, expectedToken1Out, ethIn, user1, block.timestamp + 1000);
        vm.stopPrank();
    }

    function test_swap_eth_to_exact_tokens() public {
        uint wantedTokensAmount = 1e18;
        uint userBalanceBefore = token1.balanceOf(user1);
        vm.deal(user1, 5e18);

        vm.startPrank(user1);
        token1.approve(address(router), 1e21);
        uint amountIn = router.getAmountIn(wantedTokensAmount, 1e20, 2e20);
        address[] memory path = new address[](2);
        path[0] = address(wethMock);
        path[1] = address(token1);
        router.swapETHForExactTokens{value: amountIn}(wantedTokensAmount, path, user1, block.timestamp + 1000);
        vm.stopPrank();

        assertEq(token1.balanceOf(user1) - userBalanceBefore, wantedTokensAmount);
    }

    function test_swap_exact_tokens_to_eth() public{
        uint tokenSellAmount = 1e18;
        uint userBalanceBefore = address(user1).balance;

        vm.startPrank(user1);
        token1.approve(address(router), 1e21);
        uint amountOut = router.getAmountOut(tokenSellAmount, 2e20, 1e20);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(wethMock);
        router.swapExactTokensForETH(tokenSellAmount, amountOut, path, user1, block.timestamp + 1000);
        vm.stopPrank();

        assertEq(address(user1).balance - userBalanceBefore, amountOut);
    }

    function mintLiqudity(address user, uint amount0, uint amount1) public {
        pair.sync();
        wethMock.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        pair.mint(user);
    }
}
