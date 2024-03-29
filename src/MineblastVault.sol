// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "./blast/IBlast.sol";
import "./blast/IERC20Rebasing.sol";
import './swap/MineblastSwapPair.sol';
import 'solmate/tokens/WETH.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice modified SushiSwap MiniChefV2 contract
contract MineblastVault is Ownable{
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
    IERC20[] public depositTokens;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    /// @dev Tokens added
    mapping (address => bool) public addedTokens;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    MineblastSwapPair public swapPair;
    WETH public weth = WETH(payable(0x4200000000000000000000000000000000000023));
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);
    uint64 public duration;
    uint64 public endDate;
    uint64 public lastOutputChangeDate;
    uint public unlocked;
    uint public initialSupply;
    uint public sentToLP;

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
    constructor(
        address _outputToken, 
        address _swapPair, 
        uint64 _duration
    ) Ownable(msg.sender) {
        OUTPUT_TOKEN = IERC20(_outputToken);
        swapPair = MineblastSwapPair(_swapPair);
        duration = _duration;
        endDate = uint64(block.timestamp + _duration);

        //configure gas and yield claim modes
        BLAST.configureClaimableGas();
        IERC20Rebasing(address(weth)).configure(YieldMode.CLAIMABLE);
        BLAST.configureGovernor(address(this)); 
    }

    function initialize(uint supply) onlyOwner external{
        //init farming
        add(10000, IERC20(address(weth))); 
        initialSupply = supply;
        OUTPUT_TOKEN.transferFrom(msg.sender, address(this), supply);
        setOutputPerSecond(supply / duration);
    }

    function yieldToLiquidity() public {
        uint claimable = IERC20Rebasing(address(weth)).getClaimableAmount(address(this));
        if (claimable < 1e15){
            return;
        }

        IERC20Rebasing(address(weth)).claim(address(this), claimable);
        BLAST.claimAllGas(address(this), address(this));
        weth.deposit{value: address(this).balance}();

        uint amountWETH = claimable + address(this).balance;
        uint amountToken = swapPair.getAveragePrice(uint112(amountWETH), 200);

        swapPair.sync();
        weth.transfer(address(swapPair), amountWETH);
        uint amount = amountToken == 0? 1e18 : amountToken;
        uint currentTokenBalance = IERC20(address(OUTPUT_TOKEN)).balanceOf(address(this));
        if(amount > currentTokenBalance){
            amount = currentTokenBalance;
        }

        OUTPUT_TOKEN.transfer(address(swapPair), amount);
        swapPair.mint(address(this));

        sentToLP = sentToLP + amount;
        unlocked = unlocked + outputPerSecond * (block.timestamp - lastOutputChangeDate);

        updatePool(0);
        setOutputPerSecond((initialSupply-sentToLP-unlocked)/(endDate-block.timestamp));
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _depositToken Address of the LP ERC-20 token.
    function add(uint256 allocPoint, IERC20 _depositToken) internal {
        require(addedTokens[address(_depositToken)] == false, "Token already added");
        totalAllocPoint = totalAllocPoint + allocPoint;
        depositTokens.push(_depositToken);

        poolInfo.push(PoolInfo({
            allocPoint: uint64(allocPoint),
            lastRewardTime: uint64(block.timestamp),
            accPerShare: 0
        }));
        addedTokens[address(_depositToken)] = true;
        emit LogPoolAddition(depositTokens.length - 1, allocPoint, _depositToken);
    }

    /// @notice Update the given pool's OUTPUT_TOKEN allocation point. Currently unused.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) internal {
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = uint64(_allocPoint);

        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice Sets the OUTPUT_TOKEN per second to be distributed. 
    /// @param _outputPerSecond The amount of OUTPUT_TOKEN to be distributed per second.
    function setOutputPerSecond(uint256 _outputPerSecond) internal {
        outputPerSecond = _outputPerSecond;
        lastOutputChangeDate = uint64(block.timestamp);
        emit LogOutputPerSecond(_outputPerSecond);
    }

    /// @notice View function to see pending OUTPUT_TOKEN on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending OUTPUT_TOKEN reward for a given user.
    function getPending(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPerShare = pool.accPerShare;
        uint256 lpSupply = depositTokens[_pid].balanceOf(address(this));
        uint64 lastRewardTimestamp = block.timestamp > endDate ? endDate : uint64(block.timestamp);

        if (lastRewardTimestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = lastRewardTimestamp - pool.lastRewardTime;
            uint256 reward = time * outputPerSecond * pool.allocPoint / totalAllocPoint;
            accPerShare = accPerShare + reward * ACC_PRECISION / lpSupply;
        }
        pending = uint(int256(user.amount * accPerShare / ACC_PRECISION) - user.rewardDebt);
    }

    function getUnlocked() external view returns (uint256 unlockedAmount) {
        unlockedAmount = unlocked + outputPerSecond * (block.timestamp - lastOutputChangeDate);
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

        uint64 lastRewardTimestamp = block.timestamp > endDate ? endDate : uint64(block.timestamp);

        if (lastRewardTimestamp > pool.lastRewardTime) {
            uint256 lpSupply = depositTokens[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 time = lastRewardTimestamp - pool.lastRewardTime;
                uint256 reward = time * outputPerSecond * pool.allocPoint / totalAllocPoint;
                pool.accPerShare = uint128(pool.accPerShare + reward * ACC_PRECISION / lpSupply);
            }
            pool.lastRewardTime = uint64(lastRewardTimestamp);
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

        depositTokens[pid].transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
    }

    receive() payable external {}

    function wrapAndDeposit() external payable {
        uint256 amount = msg.value;
        weth.deposit{value: amount}();

        PoolInfo memory pool = updatePool(0);
        UserInfo storage user = userInfo[0][msg.sender];

        // Effects
        user.amount = user.amount + amount;
        user.rewardDebt = user.rewardDebt + int256(amount * pool.accPerShare / ACC_PRECISION);

        emit Deposit(msg.sender, 0, amount, msg.sender);
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

        depositTokens[pid].transfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
    }

    function withdrawAndUnwrap(uint256 amount, address to) public payable {
        PoolInfo memory pool = updatePool(0);
        UserInfo storage user = userInfo[0][msg.sender];

        // Effects
        user.rewardDebt = user.rewardDebt - (int256(amount * pool.accPerShare / ACC_PRECISION));
        user.amount = user.amount - amount;

        weth.withdraw(amount);
        safeTransferETH(payable(to), amount);

        emit Withdraw(msg.sender, 0, amount, to);
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

        yieldToLiquidity();
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

        depositTokens[pid].transfer(to, amount);

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
        depositTokens[pid].transfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}