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

contract MineblastFactoryTest is BlastTest {
    MineblastSwapPairFactory public swapPairFactory;
    MineblastFactory public mineblastFactory;

    address public coinCreator = address(0x1);
    address public protocolCreator = address(0xaaa);
    address public user1 = address(0x2);
    MineblastVault vault;
    MineblastSwapPair swapPair;
    IERC20 token;
    
    uint supply = 1e21;
    uint16 creatorShare = 1000;
    uint64 duration = 10000;

    function setUp() public {

        vm.deal(user1, 1e21);
        vm.startPrank(user1);
        wethMock.deposit{value: 1e21}();
        vm.stopPrank();

        vm.startPrank(protocolCreator);
        swapPairFactory = new MineblastSwapPairFactory();
        mineblastFactory = new MineblastFactory(address(swapPairFactory));
        vm.stopPrank();

        (vault, swapPair, token) 
            = createVault(supply, creatorShare, duration);
    }

    function test_get_vault_info() public {
    (
        string memory tokenName, 
        string memory tokenSymbol, 
        uint tokenTotalSupply, 
        uint tokenPrice, 
        uint pairETHLiqudity, 
        uint pairTokenLiqudity,
        uint vaultOutputPerSecond, 
        uint vaultFarmingEndDate, 
        uint vaultFarmingDuration, 
        uint vaultUnlocked, 
        uint vaultInitialSupply, 
        uint vaultTVL, 
        uint userLockedETH, 
        uint userPending,
        uint userTokenBalance
    ) = swapPairFactory.getProjectInfo(user1, payable(address(vault)), address(swapPair), address(token));

            
        uint protocolBaseShareSetting = mineblastFactory.baseProtocolShareBps();
        uint protocolOwnerShareSetting = mineblastFactory.protocolShareFromOwnerShareBps();

        uint ownerShare = supply * creatorShare / 10000;
        uint protocolShare = supply * protocolBaseShareSetting / 10000;
        uint protocolOwnerShare = ownerShare * protocolOwnerShareSetting / 10000;
        protocolShare = protocolShare + protocolOwnerShare;
        ownerShare = ownerShare - protocolOwnerShare;
        uint vaultSupply = supply - ownerShare - protocolShare;

        assertEq(token.totalSupply(), supply);
        assertEq(token.balanceOf(coinCreator), ownerShare);
        assertEq(token.balanceOf(protocolCreator), protocolShare);
        assertEq(token.balanceOf(address(vault)), supply - ownerShare - protocolShare);

        assertEq(tokenName, "TOKEN0");
        assertEq(tokenSymbol, "TKN0");
        assertEq(tokenTotalSupply, supply);
        assertEq(tokenPrice, 0);
        assertEq(pairETHLiqudity, 0);
        assertEq(vaultOutputPerSecond, vaultSupply/duration);
        assertEq(vaultFarmingEndDate, block.timestamp + duration);
        assertEq(vaultFarmingDuration, duration);
        assertEq(vaultUnlocked, 0);
        assertEq(vaultInitialSupply, vaultSupply);
        assertEq(vaultTVL, 0);
        assertEq(userLockedETH, 0);
        assertEq(userPending, 0);
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

        vault = MineblastVault(payable(vaultAddress));
        swapPair = MineblastSwapPair(swapPairAddress);
        token = IERC20(tokenAddress);
    }

}
