// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from 'solmate/tokens/ERC20.sol';
import './blast/IBlast.sol';

contract BlastERC20 is ERC20{

    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    constructor(
        string memory _name,
        string memory _symbol,
        uint totalSupply,
        address claimer
    ) ERC20(_name, _symbol, 18){
        BLAST.configureClaimableGas();
        BLAST.configureGovernor(claimer); 

        _mint(msg.sender, totalSupply);
    }
}
