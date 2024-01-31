// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IERC20Rebasing {
  // "claimable" yield mode accounts can call this this claim their yield
  // to another address
  function claim(address recipient, uint256 amount) external returns (uint256);
  // read the claimable amount for an account
  function getClaimableAmount(address account) external view returns (uint256);
}