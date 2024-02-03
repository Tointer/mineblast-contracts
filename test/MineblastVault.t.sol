// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MineblastSwapPair} from "../src/swap/MineblastSwapPair.sol";
import {MineblastSwapPairFactory} from "../src/swap/MineblastSwapPairFactory.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {MineblastLibrary} from "../src/swap/libraries/MineblastLibrary.sol";
import {MineblastFactory} from "../src/MineblastFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/mocks/RebasingWETHMock.sol";
import "../src/MineblastVault.sol";
import "./shared/BlastTest.sol";

contract MineblastSwapPairTest is BlastTest {
    MineblastSwapPairFactory public swapPairFactory;
    MineblastFactory public mineblastFactory;

    address public coinCreator = address(0x1);
    address public protocolCreator = address(0xaaa);
    address public user1 = address(0x2);

    function setUp() public {

        wethMock.mint(user1, 1e21);

        vm.startPrank(protocolCreator);
        swapPairFactory = new MineblastSwapPairFactory();
        mineblastFactory = new MineblastFactory(address(swapPairFactory));
        vm.stopPrank();
    }

    function test_create_supply() public {
        uint supply = 1e21;
        uint16 creatorShare = 1000;
        uint64 duration = 10000;
        (MineblastVault vault, MineblastSwapPair swapPair, IERC20 token) 
            = createVault(supply, creatorShare, duration);

        uint protocolBaseShareSetting = mineblastFactory.baseProtocolShareBps();
        uint protocolOwnerShareSetting = mineblastFactory.protocolShareFromOwnerShareBps();

        uint ownerShare = supply * creatorShare / 10000;
        uint protocolShare = supply * protocolBaseShareSetting / 10000;
        uint protocolOwnerShare = ownerShare * protocolOwnerShareSetting / 10000;
        protocolShare = protocolShare + protocolOwnerShare;
        ownerShare = ownerShare - protocolOwnerShare;

        assertEq(token.totalSupply(), supply);
        assertEq(token.balanceOf(coinCreator), ownerShare);
        assertEq(token.balanceOf(protocolCreator), protocolShare);
        assertEq(token.balanceOf(address(vault)), supply - ownerShare - protocolShare);
    }

    
    function test_farm_and_harvest() public {
        uint supply = 1e21;
        uint16 creatorShare = 0;
        uint64 duration = 10000;
        (MineblastVault vault, MineblastSwapPair swapPair, IERC20 token) 
            = createVault(supply, creatorShare, duration);

        vm.startPrank(user1);
        wethMock.approve(address(vault), 1e21);
        vault.deposit(0, 1e20, user1);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + duration/2);
        vault.harvest(0, user1);
        vm.stopPrank();

        uint rewardSupply = supply - (supply * mineblastFactory.baseProtocolShareBps() / 10000);

        assertEq(token.balanceOf(user1), rewardSupply * 5000 / duration);
    }

    function test_farm_and_harvest_after_end() public {
        uint supply = 1e21;
        uint16 creatorShare = 0;
        uint64 duration = 10000;
        (MineblastVault vault, MineblastSwapPair swapPair, IERC20 token) 
            = createVault(supply, creatorShare, duration);

        vm.startPrank(user1);
        wethMock.approve(address(vault), 1e21);
        vault.deposit(0, 1e20, user1);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + duration*2);
        vault.harvest(0, user1);
        vm.stopPrank();

        uint rewardSupply = supply - (supply * mineblastFactory.baseProtocolShareBps() / 10000);

        assertEq(token.balanceOf(user1), rewardSupply);
    }

    function test_liqudity_add_empty_pool() public {
        uint supply = 1e21;
        uint16 creatorShare = 0;
        uint64 duration = 10000;
        (MineblastVault vault, MineblastSwapPair swapPair, IERC20 token) 
            = createVault(supply, creatorShare, duration);

        wethMock.setClaimable(address(vault), 1e17);

        vm.startPrank(user1);
        wethMock.approve(address(vault), 1e21);
        vault.deposit(0, 1e20, user1);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 5000);
        vault.harvest(0, user1);
        vm.stopPrank();

        uint expectedLpSupply = sqrt(1e17*1e18);
        assertEq(swapPair.totalSupply(), expectedLpSupply);
        assertEq(swapPair.balanceOf(address(vault)), expectedLpSupply - 1000);
    }

    function createVault(
        uint supply, 
        uint16 creatorShare, 
        uint64 duration
    ) public returns (MineblastVault vault, MineblastSwapPair swapPair, IERC20 token) {
        vm.startPrank(coinCreator);

        (address vaultAddress, address swapPairAddress, address tokenAddress) = 
            mineblastFactory.createVaultWithNewToken(supply, "TOKEN0", "TKN0", duration, creatorShare);

        vm.stopPrank();

        vault = MineblastVault(vaultAddress);
        swapPair = MineblastSwapPair(swapPairAddress);
        token = IERC20(tokenAddress);
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
