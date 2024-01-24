// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

contract BlastTestnetAddressBook {
    struct Addresses{
        address weth;
        address usdb;
    }

    Addresses public addresses;

    constructor() {
        addresses = Addresses({
            weth: 0x4200000000000000000000000000000000000023,
            usdb: 0x4200000000000000000000000000000000000022
        });
    }
}
