import { expect } from "chai"
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers } from "hardhat"

import { expandTo18Decimals, encodePrice } from './shared/utilities'
import { pairFixture } from './shared/fixtures'

import { MineblastSwapPairFactory } from "../typechain-types"
import { MineblastSwapPair } from "../typechain-types"
import { ERC20Mock } from "..//typechain-types"

import { Signer } from "ethers";



const MINIMUM_LIQUIDITY = 10n**3n;
const AddressZero = ethers.ZeroAddress;
const MaxUint256 = ethers.MaxUint256;

describe('UniswapV2Pair', () => {
  let factory: MineblastSwapPairFactory
  let factoryAddress: string

  let token0: ERC20Mock
  let token0Address: string

  let token1: ERC20Mock
  let token1Address: string

  let pair: MineblastSwapPair
  let pairAddress: string

  let wallets: Signer[];
  let wallet: Signer;
  let walletAddress: string;


  beforeEach(async () => {
    const fixture = await loadFixture(pairFixture)
    factory = fixture.factory
    token0 = fixture.token0
    token0Address = await token0.getAddress()
    token1 = fixture.token1
    token1Address = await token1.getAddress()
    pair = fixture.pair
    pairAddress = await pair.getAddress()
    wallets = await ethers.getSigners();
    wallet = wallets[0];
    walletAddress = await wallet.getAddress();

    await token0.approve(pairAddress, MaxUint256);
    await token1.approve(pairAddress, MaxUint256);
    await token0.mint(walletAddress, expandTo18Decimals(1000));
    await token1.mint(walletAddress, expandTo18Decimals(1000));
  })

  it('mint', async () => {
    const token0Amount = expandTo18Decimals(1)
    const token1Amount = expandTo18Decimals(4)

    const expectedLiquidity = expandTo18Decimals(2)
    await expect(pair.mint(walletAddress, token0Amount, token1Amount))
      .to.emit(pair, 'Transfer')
      .withArgs(AddressZero, AddressZero, MINIMUM_LIQUIDITY)
      .to.emit(pair, 'Transfer')
      .withArgs(AddressZero, walletAddress, expectedLiquidity - (MINIMUM_LIQUIDITY))
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount, token1Amount)
      .to.emit(pair, 'Mint')
      .withArgs(walletAddress, token0Amount, token1Amount)

    expect(await pair.totalSupply()).to.eq(expectedLiquidity)
    expect(await pair.balanceOf(walletAddress)).to.eq(expectedLiquidity - (MINIMUM_LIQUIDITY))
    expect(await token0.balanceOf(pairAddress)).to.eq(token0Amount)
    expect(await token1.balanceOf(pairAddress)).to.eq(token1Amount)
    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount)
    expect(reserves[1]).to.eq(token1Amount)
  })

  
})
