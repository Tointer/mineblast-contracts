//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import './MineblastSwapPair.sol';
import './interfaces/IMineblastSwapPairFactory.sol';
import "../MineblastVault.sol";
import "../BlastERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MineblastSwapPairFactory is IMineblastSwapPairFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(MineblastSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        MineblastSwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

     //god forgive me for I have sinned
    function getProjectInfo(address user, address payable vault, address pair, address token) 
        external view returns (
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
        ) 
    {
        address wethAddress = address(0x4200000000000000000000000000000000000023);
        tokenName = BlastERC20(token).name();
        tokenSymbol = BlastERC20(token).symbol();
        tokenTotalSupply = BlastERC20(token).totalSupply();
        tokenPrice = MineblastSwapPair(pair).getAveragePrice(1e18, 50);
        pairETHLiqudity = IERC20(wethAddress).balanceOf(pair);
        pairTokenLiqudity = IERC20(token).balanceOf(pair);
        vaultOutputPerSecond = MineblastVault(vault).outputPerSecond();
        vaultFarmingEndDate = MineblastVault(vault).endDate();
        vaultFarmingDuration = MineblastVault(vault).duration();
        vaultUnlocked = MineblastVault(vault).getUnlocked();
        vaultInitialSupply = MineblastVault(vault).initialSupply();

        vaultTVL = IERC20(wethAddress).balanceOf(vault);

        (uint256 amount,) = MineblastVault(vault).userInfo(0, user);
        userLockedETH = amount;
        userPending = MineblastVault(vault).getPending(0, user);
        userTokenBalance = IERC20(token).balanceOf(user);
    }
}
