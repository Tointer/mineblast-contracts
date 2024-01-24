// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice modified SushiSwap MiniChefV2 contract
contract MiniChefV2 is Ownable{
    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of OUTPUT_TOKEN entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of OUTPUT_TOKEN to distribute per block.
    struct PoolInfo {
        uint128 accPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    /// @notice Address of OUTPUT_TOKEN contract.
    IERC20 public immutable OUTPUT_TOKEN;

    /// @notice Info of each MCV2 pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each MCV2 pool.
    IERC20[] public lpToken;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    /// @dev Tokens added
    mapping (address => bool) public addedTokens;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    uint256 public outputPerSecond;
    uint256 private constant ACC_PRECISION = 1e12;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accPerShare);
    event LogOutputPerSecond(uint256 outputPerSecond);

    /// @param _outputToken The OUTPUT_TOKEN token contract address.
    constructor(IERC20 _outputToken) Ownable(msg.sender) {
        OUTPUT_TOKEN = _outputToken;
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    function add(uint256 allocPoint, IERC20 _lpToken) public onlyOwner {
        require(addedTokens[address(_lpToken)] == false, "Token already added");
        totalAllocPoint = totalAllocPoint + allocPoint;
        lpToken.push(_lpToken);

        poolInfo.push(PoolInfo({
            allocPoint: uint64(allocPoint),
            lastRewardTime: uint64(block.timestamp),
            accPerShare: 0
        }));
        addedTokens[address(_lpToken)] = true;
        emit LogPoolAddition(lpToken.length - 1, allocPoint, _lpToken);
    }

    /// @notice Update the given pool's OUTPUT_TOKEN allocation point. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = uint64(_allocPoint);

        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice Sets the OUTPUT_TOKEN per second to be distributed. Can only be called by the owner.
    /// @param _outputPerSecond The amount of OUTPUT_TOKEN to be distributed per second.
    function setOutputPerSecond(uint256 _outputPerSecond) public onlyOwner {
        outputPerSecond = _outputPerSecond;
        emit LogOutputPerSecond(_outputPerSecond);
    }

    /// @notice View function to see pending OUTPUT_TOKEN on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending OUTPUT_TOKEN reward for a given user.
    function pending(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPerShare = pool.accPerShare;
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = block.timestamp - pool.lastRewardTime;
            uint256 reward = time * outputPerSecond * pool.allocPoint / totalAllocPoint;
            accPerShare = accPerShare + reward * ACC_PRECISION / lpSupply;
        }
        pending = uint(int256(user.amount * accPerShare / ACC_PRECISION) - user.rewardDebt);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 time = block.timestamp - pool.lastRewardTime;
                uint256 reward = time * outputPerSecond * pool.allocPoint / totalAllocPoint;
                pool.accPerShare = uint128(pool.accPerShare + reward * ACC_PRECISION / lpSupply);
            }
            pool.lastRewardTime = uint64(block.timestamp);
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accPerShare);
        }
    }

    /// @notice Deposit LP tokens to MCV2 for OUTPUT_TOKEN allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        // Effects
        user.amount = user.amount + amount;
        user.rewardDebt = user.rewardDebt + int256(amount * pool.accPerShare / ACC_PRECISION);

        lpToken[pid].transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
    }

    /// @notice Withdraw LP tokens from MCV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        // Effects
        user.rewardDebt = user.rewardDebt - (int256(amount * pool.accPerShare / ACC_PRECISION));
        user.amount = user.amount - amount;

        lpToken[pid].transfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of OUTPUT_TOKEN rewards.
    function harvest(uint256 pid, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulated = int256(user.amount * pool.accPerShare / ACC_PRECISION);
        uint256 _pending = uint(accumulated - user.rewardDebt);

        // Effects
        user.rewardDebt = accumulated;

        // Interactions
        if (_pending != 0) {
            OUTPUT_TOKEN.transfer(to, _pending);
        }

        emit Harvest(msg.sender, pid, _pending);
    }

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and OUTPUT_TOKEN rewards.
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulated = int256(user.amount * pool.accPerShare / ACC_PRECISION);
        uint256 _pending = uint(accumulated -user.rewardDebt);

        // Effects
        user.rewardDebt = accumulated - (int256(amount * pool.accPerShare / ACC_PRECISION));
        user.amount = user.amount - amount;

        // Interactions
        OUTPUT_TOKEN.transfer(to, _pending);

        lpToken[pid].transfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pending);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) public {
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].transfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }
}