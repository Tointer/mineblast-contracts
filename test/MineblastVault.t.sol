// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MineblastSwapPair} from "../src/swap/MineblastSwapPair.sol";
import {MineblastSwapPairFactory} from "../src/swap/MineblastSwapPairFactory.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {MineblastLibrary} from "../src/swap/libraries/MineblastLibrary.sol";
import {MineblastFactory} from "../src/MineblastFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/mocks/BlastMock.sol";
import "../src/mocks/RebasingWETHMock.sol";

contract MineblastSwapPairTest is Test {
    MineblastSwapPairFactory public swapPairFactory;
    MineblastFactory public mineblastFactory;

    address public coinCreator = address(0x1);
    address public protocolCreator = address(0xaaa);

    function setUp() public {
        setUpBlastEnv();

        vm.startPrank(protocolCreator);
        swapPairFactory = new MineblastSwapPairFactory();
        mineblastFactory = new MineblastFactory(address(swapPairFactory));
        vm.stopPrank();
    }

    function test_create_with_new_token() public {
        uint supply = 1e21;
        uint16 creatorShare = 1000;
        uint64 duration = 10000;

        vm.startPrank(coinCreator);

        (address vaultAddress, address tokenAddress) = 
            mineblastFactory.createVaultWithNewToken(supply, "TOKEN0", "TKN0", duration, creatorShare);

        vm.stopPrank();
    }

    function test_create_supply() public {
        uint supply = 1e21;
        uint16 creatorShare = 1000;
        uint64 duration = 10000;

        vm.startPrank(coinCreator);

        (address vaultAddress, address tokenAddress) = 
            mineblastFactory.createVaultWithNewToken(supply, "TOKEN0", "TKN0", duration, creatorShare);

        vm.stopPrank();

        IERC20 token = IERC20(tokenAddress);

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
        assertEq(token.balanceOf(vaultAddress), supply - ownerShare - protocolShare);
    }

    function setUpBlastEnv() public{
        BlastMock blastMock = new BlastMock();
        bytes memory blastCode = address(blastMock).code;
        address blastTargetAddress = address(0x4300000000000000000000000000000000000002);
        vm.etch(blastTargetAddress, blastCode);

        RebasingWETHMock wethMock = new RebasingWETHMock();
        bytes memory wethCode = address(wethMock).code;
        address wethTargetAddress = address(0x4200000000000000000000000000000000000023);
        vm.etch(wethTargetAddress, wethCode);
    }
}
