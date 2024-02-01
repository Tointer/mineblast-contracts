// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../blast/IBlast.sol";

contract BlastMock is IBlast {
    // configure
    function configureContract(address, YieldMode, GasMode, address) external override {}

    function configure(YieldMode, GasMode, address) external override {}

    // base configuration options
    function configureClaimableYield() external override {}

    function configureClaimableYieldOnBehalf(address) external override {}

    function configureAutomaticYield() external override {}

    function configureAutomaticYieldOnBehalf(address) external override {}

    function configureVoidYield() external override {}

    function configureVoidYieldOnBehalf(address) external override {}

    function configureClaimableGas() external override {}

    function configureClaimableGasOnBehalf(address) external override {}

    function configureVoidGas() external override {}

    function configureVoidGasOnBehalf(address) external override {}

    function configureGovernor(address) external override {}

    function configureGovernorOnBehalf(address, address) external override {}

    // claim yield
    function claimYield(address, address, uint256) external override returns (uint256) {
        return 0;
    }

    function claimAllYield(address, address) external override returns (uint256) {
        return 0;
    }

    // claim gas
    function claimAllGas(address, address) external override returns (uint256) {
        return 0;
    }

    function claimGasAtMinClaimRate(address, address, uint256) external override returns (uint256) {
        return 0;
    }

    function claimMaxGas(address, address) external override returns (uint256) {
        return 0;
    }

    function claimGas(address, address, uint256, uint256) external override returns (uint256) {
        return 0;
    }

    // read functions
    function readClaimableYield(address) external view override returns (uint256) {
        return 0;
    }

    function readYieldConfiguration(address) external view override returns (uint8) {
        return 0;
    }

    function readGasParams(address) external view override returns (uint256, uint256, uint256, GasMode) {
        return (0, 0, 0, GasMode.CLAIMABLE);
    }
}