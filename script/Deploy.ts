import { run} from "hardhat"
import { MineblastSwapPairFactory, MineblastFactory, MineblastRouter, MineblastLibrary} from "../typechain-types";
import hre from "hardhat";
import { ethers } from "hardhat"
import { libraries } from "../typechain-types/src/swap";


async function main() {
    const wethAddress = "0x4200000000000000000000000000000000000023";
    const supply = 10n ** 27n;
    const creatorShare = 1000;
    const duration = 20*24*60*60;

    const MineblastLibrary = await ethers.getContractFactory("MineblastLibrary");
    const mineblastLibrary = await MineblastLibrary.deploy();
    const mineblastLibraryAddress = await mineblastLibrary.getAddress();
    console.log("Mineblast library deployed to:", mineblastLibraryAddress);

    const MineblastSwapPairFactory = await ethers.getContractFactory("MineblastSwapPairFactory");
    const pairFactory = await MineblastSwapPairFactory.deploy();
    const pairFactoryAddress = await pairFactory.getAddress();
    console.log("Pair factory deployed to:", pairFactoryAddress);

    const MineblastFactory = await ethers.getContractFactory("MineblastFactory");
    const mineblastFactory = await MineblastFactory.deploy(pairFactoryAddress);
    const mineblastFactoryAddress = await mineblastFactory.getAddress();
    console.log("Mineblast factory deployed to:", mineblastFactoryAddress);

    const MineblastRouter = await ethers.getContractFactory("MineblastRouter", {
        libraries: {
            MineblastLibrary: mineblastLibraryAddress
        }
    });
    const mineblastRouter = await MineblastRouter.deploy(mineblastFactoryAddress, wethAddress);
    const mineblastRouterAddress = await mineblastRouter.getAddress();
    console.log("Mineblast router deployed to:", mineblastRouterAddress);

    await mineblastFactory.createVaultWithNewToken(supply, "MIBTestToken", "tMIB", duration, creatorShare);

    //sleep for 15 seconds
    await new Promise(r => setTimeout(r, 15000));
    await mineblastFactory.waitForDeployment();

    await verify(pairFactoryAddress, []);
    await verify(mineblastFactoryAddress, [pairFactoryAddress]);
    await verify(mineblastRouterAddress, [mineblastFactoryAddress, wethAddress]);
}


const verify = async (contractAddress: string, args: any) => {
    console.log("Verifying contract...")
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        })
    } catch (e: any) {
        if (e.message.toLowerCase().includes("already verified")) {
            console.log("Already verified!")
        } else {
            console.log(e)
        }
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });