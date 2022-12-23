pragma solidity ^0.8;
contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;
    IERC20 public immutable usdtToken;
    Team public immutable team;
    IUniswapV2Router01 public immutable mdexSwap;
    IUniswapV2Router01 public immutable Swap;


    address public nagaToken;
    address public uToken;
    uint public USDTnum;



    uint private time0 = 2592000;
    uint private time1 = 7776000;
    uint private time2 = 15552000;
    uint private time3 = 31104000;

    address public teamAdr;
    address public owner;


    uint public duration;


    uint public finishAt;


    uint public updatedAt;


    uint public rewardRate;



    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;

    mapping(address => uint) public rewards;


    uint public totalSupply;

    mapping(address => uint) public balanceOf;

    mapping(address => uint) public userTime;
    bool public pause;

    constructor(address _stakingToken, address _rewardToken,address _uToken,address _swapToken,address _team) {
        owner = msg.sender;

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
        usdtToken = IERC20(_uToken);

        nagaToken = _stakingToken;
        uToken = _uToken;
        Swap = IUniswapV2Router01(_swapToken);
        mdexSwap = IUniswapV2Router01(0x0f1c2D1FDD202768A4bDa7A38EB0377BD58d278E);
        team = Team(_team);
        teamAdr = _team;
        pause = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }


    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(finishAt, block.timestamp);
    }


    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }




    function stake(uint _amount,uint _unum,uint _type) external updateReward(msg.sender) {
        require(pause, "not start");
        require(team.isCan(msg.sender), "you not team");

        require(_amount > 0, "amount = 0");
        require(_unum > 0, "unum = 0");

        require(_type <= 3, "type is error");
        require(userTime[msg.sender] == 0, "you have a stake");

        uint x = getOut(_unum);
        uint min = _amount*291/700;
        uint max = _amount*309/700;
        require(x >= min , "USDT is not enough");
        require(x <= max , "USDT is out");
        USDTnum = USDTnum + _unum;
        stakingToken.transferFrom(msg.sender, address(this), _amount);


        if(_type == 0){
            userTime[msg.sender] = block.timestamp + time0;
        }
        if(_type == 1){
            userTime[msg.sender] = block.timestamp + time1;
        }
        if(_type == 2){
            userTime[msg.sender] = block.timestamp + time2;
        }
        if(_type == 3){
            userTime[msg.sender] = block.timestamp + time3;
        }
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;

        uint t_num = _unum*15/100;
        team.setBalance(msg.sender,t_num);

        usdtToken.transferFrom(msg.sender, address(this), _unum-t_num);
        usdtToken.transferFrom(msg.sender, teamAdr, t_num);
    }

    function addStake(uint _amount,uint _unum) external updateReward(msg.sender) {
        require(pause, "not start");
        require(_amount > 0, "amount = 0");
        require(_unum > 0, "unum = 0");

        require(userTime[msg.sender] >  block.timestamp, "you not have a stake");

        uint x = getOut(_unum);
        uint min = _amount*291/700;
        uint max = _amount*309/700;
        require(x >= min , "USDT is not enough");
        require(x <= max , "USDT is out");
        USDTnum = USDTnum + _unum;
        stakingToken.transferFrom(msg.sender, address(this), _amount);


        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;


        uint t_num = _unum*15/100;
        team.setBalance(msg.sender,t_num);

        usdtToken.transferFrom(msg.sender, address(this), _unum-t_num);
        usdtToken.transferFrom(msg.sender, teamAdr, t_num);
    }


    function withdraw() external updateReward(msg.sender) {
        require(balanceOf[msg.sender] > 0, "balance = 0");
        require(userTime[msg.sender] <= block.timestamp, "your stake unexpired");
        totalSupply -= balanceOf[msg.sender];
        stakingToken.transfer(msg.sender, balanceOf[msg.sender]);
        balanceOf[msg.sender] = 0;
		userTime[msg.sender] = 0;
    }

    function earned(address _account) public view returns (uint) {
        return
            ((balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }


    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }


    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount)
        external
        onlyOwner
        updateReward(address(0))
    {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function getUserxpect (address _account)public view returns (uint) {
           return
            balanceOf[_account] / totalSupply * rewardRate * userTime[_account];
    }

    function getOut(uint _num)  public view returns (uint x){
        address[] memory t = new address[](2);

        t[0] = uToken;
        t[1] = nagaToken;
        uint[] memory amounts = mdexSwap.getAmountsOut(_num,t);
        x = amounts[1];
        return x;
    }



    function getRewards() external onlyOwner{
        uint num = usdtToken.balanceOf(address(this));
        usdtToken.transfer(msg.sender, num);

    }

    function transferOwner(address _newOwner) external onlyOwner{
        owner = _newOwner;
    }
    function setPause(bool _bool) external onlyOwner{
         pause = _bool;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IUniswapV2Router01 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface Team{
function setBalance(address _adr,uint _num)external;
function isCan(address _adr)  external view returns (bool);
}
