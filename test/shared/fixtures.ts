import { expect } from "chai"
import { ethers } from "hardhat"

import { expandTo18Decimals } from './utilities'
import { MineblastSwapPairFactory } from "../../typechain-types"
import { MineblastSwapPair } from "../../typechain-types"
import { ERC20Mock } from "../../typechain-types"


interface FactoryFixture {
  factory: MineblastSwapPairFactory
}

export async function factoryFixture(): Promise<FactoryFixture> {
  const factory = await ethers.deployContract("MineblastSwapPairFactory")
  return { factory }
}

interface PairFixture extends FactoryFixture {
  token0: ERC20Mock
  token1: ERC20Mock
  pair: MineblastSwapPair
}

export async function pairFixture(): Promise<PairFixture> {
  const factory = await ethers.deployContract("MineblastSwapPairFactory")

  const tokenAFactory = await ethers.getContractFactory("ERC20Mock");
  const tokenA = await tokenAFactory.deploy("Token A", "TKA", 18);
  const tokenB = await tokenAFactory.deploy("Token B", "TKB", 18);

  await factory.createPair(tokenA, tokenB)
  const pairAddress = await factory.getPair(tokenA, tokenB)
  const pair = await ethers.getContractAt("MineblastSwapPair", pairAddress);

  const token0Address = (await pair.token0());
  const token0 = (await tokenA.getAddress()) === token0Address ? tokenA : tokenB
  const token1 = (await tokenA.getAddress()) === token0Address ? tokenB : tokenA

  return { factory, token0, token1, pair }
}
