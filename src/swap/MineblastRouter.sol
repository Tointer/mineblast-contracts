//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import './libraries/MineblastLibrary.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../blast/IERC20Rebasing.sol";
import './MineblastSwapPair.sol';
import {WETH} from 'solmate/tokens/WETH.sol';
import {IBlast} from '../blast/IBlast.sol';

contract MineblastRouter {
    address public immutable factory;
    address payable public immutable WETHaddr;
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'MineblastRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address payable _WETHaddr) {
        factory = _factory;
        WETHaddr = _WETHaddr;

        BLAST.configureClaimableGas();
        BLAST.configureGovernor(msg.sender); 
    }

    receive() external payable {
        assert(msg.sender == WETHaddr); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // CHANGED: in mineblast, pair always exists, since it created along with token
        (uint reserveA, uint reserveB) = MineblastLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MineblastLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MineblastRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = MineblastLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MineblastRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = MineblastLibrary.pairFor(factory, tokenA, tokenB);

        MineblastSwapPair(pair).sync();
        safeTransferFrom(tokenA, msg.sender, pair, amountA);
        safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = MineblastSwapPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        address pair = MineblastLibrary.pairFor(factory, token, WETHaddr);
        MineblastSwapPair(pair).sync();
        
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETHaddr,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        safeTransferFrom(token, msg.sender, pair, amountToken);
        WETH(WETHaddr).deposit{value: amountETH}();
        assert(WETH(WETHaddr).transfer(pair, amountETH));
        liquidity = MineblastSwapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = MineblastLibrary.pairFor(factory, tokenA, tokenB);
        MineblastSwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = MineblastSwapPair(pair).burn(to);
        (address token0,) = MineblastLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'MineblastRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'MineblastRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETHaddr,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        safeTransfer(token, to, amountToken);
        WETH(WETHaddr).withdraw(amountETH);
        safeTransferETH(to, amountETH);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MineblastLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? MineblastLibrary.pairFor(factory, output, path[i + 2]) : _to;
            if(i != 0) MineblastSwapPair(MineblastLibrary.pairFor(factory, input, output)).sync();
            MineblastSwapPair(MineblastLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        MineblastSwapPair(MineblastLibrary.pairFor(factory, path[0], path[1])).sync();
        amounts = MineblastLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MineblastRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        safeTransferFrom(
            path[0], msg.sender, MineblastLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        MineblastSwapPair(MineblastLibrary.pairFor(factory, path[0], path[1])).sync();
        amounts = MineblastLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MineblastRouter: EXCESSIVE_INPUT_AMOUNT');
        
        safeTransferFrom(
            path[0], msg.sender, MineblastLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
    
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETHaddr, 'MineblastRouter: INVALID_PATH');
        MineblastSwapPair(MineblastLibrary.pairFor(factory, path[0], path[1])).sync();
        amounts = MineblastLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MineblastRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        WETH(WETHaddr).deposit{value: amounts[0]}();
        assert(WETH(WETHaddr).transfer(MineblastLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETHaddr, 'MineblastRouter: INVALID_PATH');
        MineblastSwapPair(MineblastLibrary.pairFor(factory, path[0], path[1])).sync();
        amounts = MineblastLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'MineblastRouter: EXCESSIVE_INPUT_AMOUNT');
        safeTransferFrom(
            path[0], msg.sender, MineblastLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        WETH(WETHaddr).withdraw(amounts[amounts.length - 1]);
        safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
    
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETHaddr, 'MineblastRouter: INVALID_PATH');
        MineblastSwapPair(MineblastLibrary.pairFor(factory, path[0], path[1])).sync();
        amounts = MineblastLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'MineblastRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        safeTransferFrom(
            path[0], msg.sender, MineblastLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        WETH(WETHaddr).withdraw(amounts[amounts.length - 1]);
        safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
    
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETHaddr, 'MineblastRouter: INVALID_PATH');
        MineblastSwapPair(MineblastLibrary.pairFor(factory, path[0], path[1])).sync();
        amounts = MineblastLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'MineblastRouter: EXCESSIVE_INPUT_AMOUNT');
        WETH(WETHaddr).deposit{value: amounts[0]}();
        assert(WETH(WETHaddr).transfer(MineblastLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) safeTransferETH(msg.sender, msg.value - amounts[0]);
    }


    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return MineblastLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
    
        returns (uint amountOut)
    {
        return MineblastLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
    
        returns (uint amountIn)
    {
        return MineblastLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
    
        returns (uint[] memory amounts)
    {
        return MineblastLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
    
        returns (uint[] memory amounts)
    {
        return MineblastLibrary.getAmountsIn(factory, amountOut, path);
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}