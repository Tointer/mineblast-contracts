import { expect } from "chai"
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers } from "hardhat"

import { expandTo18Decimals, encodePrice } from './shared/utilities'
import { pairFixture } from './shared/fixtures'

import { MineblastSwapPairFactory } from "../../typechain-types"
import { MineblastSwapPair } from "../../typechain-types"
import { ERC20Mock } from "../../typechain-types"

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
    await token0.mint(walletAddress, expandTo18Decimals(10000));
    await token1.mint(walletAddress, expandTo18Decimals(10000));
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

  async function addLiquidity(token0Amount: bigint, token1Amount: bigint) {
    await pair.mint(walletAddress, token0Amount, token1Amount)
  }
  const swapTestCases: bigint[][] = [
    [1, 5, 10, '1662497915624478906'],
    [1, 10, 5, '453305446940074565'],

    [2, 5, 10, '2851015155847869602'],
    [2, 10, 5, '831248957812239453'],

    [1, 10, 10, '906610893880149131'],
    [1, 100, 100, '987158034397061298'],
    [1, 1000, 1000, '996006981039903216']
  ].map(a => a.map(n => (typeof n === 'string' ? BigInt(n) : expandTo18Decimals(n))))
  swapTestCases.forEach((swapTestCase, i) => {
    it(`getInputPrice:${i}`, async () => {
      const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase
      await addLiquidity(token0Amount, token1Amount)
      await expect(pair.swap(swapAmount, 0, 0, expectedOutputAmount + (1n), walletAddress, '0x')).to.be.revertedWith(
        'UniswapV2: K'
      )
      await pair.swap(swapAmount, 0, 0, expectedOutputAmount, walletAddress, '0x')
    })
  })

  const optimisticTestCases: bigint[][] = [
    ['997000000000000000', 5, 10, 1], // given amountIn, amountOut = floor(amountIn * .997)
    ['997000000000000000', 10, 5, 1],
    ['997000000000000000', 5, 5, 1],
    [1, 5, 5, '1003009027081243732'] // given amountOut, amountIn = ceiling(amountOut / .997)
  ].map(a => a.map(n => (typeof n === 'string' ? BigInt(n) : expandTo18Decimals(n))))
  optimisticTestCases.forEach((optimisticTestCase, i) => {
    it(`optimistic:${i}`, async () => {
      const [outputAmount, token0Amount, token1Amount, inputAmount] = optimisticTestCase
      await addLiquidity(token0Amount, token1Amount)
      await expect(pair.swap(inputAmount, 0, outputAmount+(1n), 0, walletAddress, '0x')).to.be.revertedWith(
        'UniswapV2: K'
      )
      await pair.swap(inputAmount, 0, outputAmount, 0, walletAddress, '0x')
    })
  })

  it('swap:token0', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigInt('1662497915624478906')
    await expect(pair.swap(swapAmount, 0, 0, expectedOutputAmount, walletAddress, '0x'))
      .to.emit(token1, 'Transfer')
      .withArgs(pairAddress, walletAddress, expectedOutputAmount)
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount+(swapAmount), token1Amount-(expectedOutputAmount))
      .to.emit(pair, 'Swap')
      .withArgs(walletAddress, swapAmount, 0, 0, expectedOutputAmount, walletAddress)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount+(swapAmount))
    expect(reserves[1]).to.eq(token1Amount-(expectedOutputAmount))
    expect(await token0.balanceOf(pairAddress)).to.eq(token0Amount+(swapAmount))
    expect(await token1.balanceOf(pairAddress)).to.eq(token1Amount-(expectedOutputAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(walletAddress)).to.eq(totalSupplyToken0-(token0Amount)-(swapAmount))
    expect(await token1.balanceOf(walletAddress)).to.eq(totalSupplyToken1-(token1Amount)+(expectedOutputAmount))
  })

  it('swap:token1', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigInt('453305446940074565')
    await expect(pair.swap(0, swapAmount, expectedOutputAmount, 0, walletAddress, '0x'))
      .to.emit(token0, 'Transfer')
      .withArgs(pairAddress, walletAddress, expectedOutputAmount)
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount-(expectedOutputAmount), token1Amount+(swapAmount))
      .to.emit(pair, 'Swap')
      .withArgs(walletAddress, 0, swapAmount, expectedOutputAmount, 0, walletAddress)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount-(expectedOutputAmount))
    expect(reserves[1]).to.eq(token1Amount+(swapAmount))
    expect(await token0.balanceOf(pairAddress)).to.eq(token0Amount-(expectedOutputAmount))
    expect(await token1.balanceOf(pairAddress)).to.eq(token1Amount+(swapAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(walletAddress)).to.eq(totalSupplyToken0-(token0Amount)+(expectedOutputAmount))
    expect(await token1.balanceOf(walletAddress)).to.eq(totalSupplyToken1-(token1Amount)-(swapAmount))
  })

  it('burn', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const expectedLiquidity = expandTo18Decimals(3)
    await pair.transfer(pairAddress, expectedLiquidity - (MINIMUM_LIQUIDITY))
    await expect(pair.burn(walletAddress))
      .to.emit(pair, 'Transfer')
      .withArgs(pairAddress, AddressZero, expectedLiquidity - (MINIMUM_LIQUIDITY))
      .to.emit(token0, 'Transfer')
      .withArgs(pairAddress, walletAddress, token0Amount - (1000n))
      .to.emit(token1, 'Transfer')
      .withArgs(pairAddress, walletAddress, token1Amount - (1000n))
      .to.emit(pair, 'Sync')
      .withArgs(1000, 1000)
      .to.emit(pair, 'Burn')
      .withArgs(walletAddress, token0Amount - (1000n), token1Amount - (1000n), walletAddress)

    expect(await pair.balanceOf(walletAddress)).to.eq(0)
    expect(await pair.totalSupply()).to.eq(MINIMUM_LIQUIDITY)
    expect(await token0.balanceOf(pairAddress)).to.eq(1000)
    expect(await token1.balanceOf(pairAddress)).to.eq(1000)
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(walletAddress)).to.eq(totalSupplyToken0 - (1000n))
    expect(await token1.balanceOf(walletAddress)).to.eq(totalSupplyToken1 - (1000n))
  })

  // it('price{0,1}CumulativeLast', async () => {
  //   const token0Amount = expandTo18Decimals(3)
  //   const token1Amount = expandTo18Decimals(3)
  //   await addLiquidity(token0Amount, token1Amount)

  //   const blockTimestamp = (await pair.getReserves())[2]
  //   await mineBlock(provider, blockTimestamp + 1)
  //   await pair.sync(overrides)

  //   const initialPrice = encodePrice(token0Amount, token1Amount)
  //   expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0])
  //   expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1])
  //   expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 1)

  //   const swapAmount = expandTo18Decimals(3)
  //   await token0.transfer(pairAddress, swapAmount)
  //   await mineBlock(provider, blockTimestamp + 10)
  //   // swap to a new price eagerly instead of syncing
  //   await pair.swap(0, expandTo18Decimals(1), walletAddress, '0x', overrides) // make the price nice

  //   expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10))
  //   expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10))
  //   expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 10)

  //   await mineBlock(provider, blockTimestamp + 20)
  //   await pair.sync(overrides)

  //   const newPrice = encodePrice(expandTo18Decimals(6), expandTo18Decimals(2))
  //   expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10).add(newPrice[0].mul(10)))
  //   expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10).add(newPrice[1].mul(10)))
  //   expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 20)
  // })
})
