// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./MineblastVault.sol";
import "./BlastERC20.sol";
import "./swap/interfaces/IMineblastSwapPairFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MineblastFactory is Ownable{
    event VaultCreated(address vault, address pair, address token);

    IMineblastSwapPairFactory public swapPairFactory;
    address public wethAddress = address(0x4200000000000000000000000000000000000023);

    uint16 public constant maxOwnerShareBps = 1000; //10%
    uint16 public constant baseProtocolShareBps = 50; //0.5%
    uint16 public constant protocolShareFromOwnerShareBps = 500; //5% from owner share

    VaultInfo[] public allVaults;

    struct VaultInfo {
        address vault;
        address pair;
        address token;
    }

    constructor(address _swapPairFactory) Ownable(msg.sender) {
        swapPairFactory = IMineblastSwapPairFactory(_swapPairFactory);
    }

    // function createVaultWithExistingToken(
    //     uint amount,
    //     address token, 
    //     uint64 duration
    // ) external returns (address) {
    //     require(amount > 0, "Amount must be greater than 0");

    //     address pairAddress = getPairCreateIfNeeded(wethAddress, token);
    //     MineblastVault vault = new MineblastVault(token, pairAddress, duration);

    //     uint protocolCut = amount * baseProtocolShareBps / 10000;
    //     uint finalAmount = amount - protocolCut;

    //     IERC20(token).transfer(owner(), protocolCut);
    //     IERC20(token).approve(address(vault), finalAmount);
    //     vault.initialize(finalAmount);
    //     return address(vault);
    // }

    function createVaultWithNewToken(
        uint supply,
        string memory name, 
        string memory symbol, 
        uint64 duration,
        uint16 ownerSupplyBps
    ) external returns (address vaultAddress, address pairAddress, address tokenAddress) {
        require(supply > 0, "supply must be greater than 0");
       
        BlastERC20 token = new BlastERC20(name, symbol, supply, msg.sender);
        pairAddress = getPairCreateIfNeeded(wethAddress, address(token));
        MineblastVault vault = new MineblastVault(address(token), pairAddress, duration);

        (uint ownerSupply, uint protocolCut,  uint finalAmount) = calculateShares(supply, ownerSupplyBps);

        token.transfer(msg.sender, ownerSupply);
        token.transfer(owner(), protocolCut);

        token.approve(address(vault), finalAmount);
        vault.initialize(finalAmount);

        allVaults.push(VaultInfo(address(vault), pairAddress, address(token)));
        emit VaultCreated(address(vault), pairAddress, address(token));
        
        return (address(vault), pairAddress, address(token));
    }

    function calculateShares(
        uint supply,
        uint16 ownerSupplyBps
    ) internal pure returns (uint ownerSupply, uint protocolCut, uint finalAmount) {
        require(ownerSupplyBps <= maxOwnerShareBps, "Owner supply must be less than or equal to the max owner share");
        
        ownerSupply = supply * ownerSupplyBps / 10000;
        uint protocolBaseCut = supply * baseProtocolShareBps / 10000;
        uint protocolOwnerCut = ownerSupply * protocolShareFromOwnerShareBps / 10000;
        ownerSupply = ownerSupply - protocolOwnerCut;
        protocolCut = protocolBaseCut + protocolOwnerCut;
        finalAmount = supply - ownerSupply - protocolCut;
    }

    function getPairCreateIfNeeded(
        address tokenA, 
        address tokenB
    ) internal returns (address) {
        address existingPool = swapPairFactory.getPair(tokenA, tokenB);
        if (existingPool == address(0)) {
            return swapPairFactory.createPair(tokenA, tokenB);
        }
        return existingPool;
    }
}
