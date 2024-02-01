// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {WETH} from 'solmate/tokens/WETH.sol';
import "../blast/IERC20Rebasing.sol";

contract RebasingWETHMock is WETH, IERC20Rebasing{
    mapping(address => uint) public claimable;

    function mint(address _to, uint _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) external {
        _burn(_from, _amount);
    }

    function setClaimable(address account, uint amount) external {
        claimable[account] = amount;
    }

    function configure(YieldMode) external override returns (uint){
        return 0;
    }

    function claim(address recipient, uint amount) external override returns (uint){
        _mint(recipient, amount);
        claimable[msg.sender] -= amount;

        return amount;
    }

    function getClaimableAmount(address account) external override view returns (uint){
        return claimable[account];
    }
}
