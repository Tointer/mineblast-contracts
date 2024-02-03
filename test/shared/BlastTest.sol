// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/mocks/BlastMock.sol";
import "../../src/mocks/RebasingWETHMock.sol";

abstract contract BlastTest is Test {

    RebasingWETHMock public wethMock;
    BlastMock public blastMock;

    constructor() {
        setUpMockBlastEnv();
    }
 
    function setUpMockBlastEnv() internal {
        BlastMock blastMockContract = new BlastMock();
        bytes memory blastCode = address(blastMockContract).code;
        address blastTargetAddress = address(0x4300000000000000000000000000000000000002);
        vm.etch(blastTargetAddress, blastCode);
        blastMock = BlastMock(blastTargetAddress);

        RebasingWETHMock wethMockContract = new RebasingWETHMock();
        bytes memory wethCode = address(wethMockContract).code;
        address wethTargetAddress = address(0x4200000000000000000000000000000000000023);
        vm.etch(wethTargetAddress, wethCode);
        wethMock = RebasingWETHMock(payable(wethTargetAddress));
    }
}