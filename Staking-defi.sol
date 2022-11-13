// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.15;

abstract contract Context 
{
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


interface IUniswapV2Factory 
{
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}


// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
}



interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}


interface IUniswapV2Router02 is IUniswapV2Router01 
{
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


interface IBEP20 
{
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() 
    {
        _setOwner(_msgSender());
    }


    function owner() public view virtual returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        _setOwner(address(0));
    }


    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private 
    {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

}


interface IBEP20Metadata is IBEP20 
{
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}



contract Codia is Context, IBEP20, IBEP20Metadata, Ownable 
{
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    mapping(address => uint256) internal stakes; // staked amount
    mapping(address => uint256) internal holderAlreadyWithDrawn; // total withdrawal amount

    mapping(address => uint256) internal stakingTimestamp; //when tokens were staked. 

    mapping(string => uint256) internal busdInternalBalances;
    mapping(string => uint256) internal tokenInternalBalances;


    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 _decimals;
    address[] internal stakeholders;
    bool stakingOpen = true;

    uint256 public rewardDistributionIndex = 0;
    uint256 public _totalStakes = 0;
    uint256 public oneDaySeconds = 3; //86400; // 1 day
    uint256 public initialPd = 30;
    uint256 public sellableTokens;
    uint256 public soldOutTokens = 0;
    uint256 public tokensPerBusd = 10;

    uint256 public tokenDeploymentTimestamp = block.timestamp;
    uint256 public lastStakingTokenInfusionTimestamp = block.timestamp;
    uint256 public totalInfusedTokens = 0;

    address[] sponsors = [0xe743684437245F4bB5bc8311cF53Af387d2C4Cc6, 
                          0x4f07daEA862D10983B9c3416cB4D5117e23654F5, 
                          0xc5178A595EfAEFf2c01ac2f26BA48B4121Eb4B7E, 
                          0x0572689b9Cb91789325C32E5f4b3d2b6A4e7D526, 
                          0xdb995a5e8564Af80C411374fAf951cE267558DAA, 
                          0x8A911e1afF89a0A58E224Da43E8E4D8A4d756614];
    
    address BUSD = 0xd9145CCE52D386f254917e481eB44e9943F39138; //0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;

    constructor()
    { 
        _name = "Codia";
        _symbol = "CORDIA";
        _decimals = 18;
        _totalSupply = 1000_000_000 * 10**_decimals;
        tokenInternalBalances["liquidity"] = 50_000_000 * 10**_decimals;
        tokenInternalBalances["forsell"] = 950_000_000 * 10**_decimals;

        _balances[address(this)] = _totalSupply;
        emit Transfer(address(0), address(this), _totalSupply);
    }


    function name() public view virtual override returns (string memory) {
        return _name;
    }


    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }


    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }


    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }


    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) 
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) 
    {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) 
    {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }


    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) 
    {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }


    function _transfer(address sender, address recipient, uint256 amount) internal virtual 
    {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        _transferTokens(sender, recipient, amount);
    }




    function _transferTokens(address sender, address recipient, uint256 amount) internal
    {
        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }


    function _approve(address owner, address spender,  uint256 amount) internal virtual 
    {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

///----- GET WALLETS ADDRESSES --- ////

function getD1Wallet() public view returns(address) { return sponsors[0]; }
function getD2Wallet() public view returns(address) { return sponsors[1]; }
function getM1Wallet() public view returns(address) { return sponsors[2]; }
function getM2Wallet() public view returns(address) { return sponsors[3]; }
function getM3Wallet() public view returns(address) { return sponsors[4]; }
function getAdminWallet() public view returns(address) { return sponsors[5]; }


////------ SALE START ------////

    bool private sellHasStarted=false;

    function startSale () external onlyOwner returns (bool)
    {
        sellHasStarted=true;
        return true;
    }


    function pauseSale() external onlyOwner returns (bool)
    {
        sellHasStarted=false;
        return true;
    }



    function getTokensPrice(uint256 _amount) public view returns(uint256)
    {
        uint256 price =  _amount.div(tokensPerBusd);
        return price;
    }

    function getBusdBalanceInBuyerWallet() public view returns (uint256)
    {
        uint256 busdBalance = IBEP20(BUSD).balanceOf(msg.sender);
        return busdBalance;
    }


    function approvedBusdAmountByBuyer() public view returns (uint256)
    {
        uint256 busdBalance = IBEP20(BUSD).allowance(msg.sender, address(this));
        return busdBalance;
    }


    //Amount should be in Cordia Token
    // Approval of BUSD is require before approval. 
    // Busd balance in connected wallet should more than required busd. 
   function buyToken(uint256 _amount) public
   {
       uint256 _price =  getTokensPrice(_amount);
       require(sellHasStarted==true,"Sale is not started");
       require(_amount<=sellableTokens, "Not Enough Tokens in this Sale");

       uint256 buyerBusdBalance = getBusdBalanceInBuyerWallet();
       require(buyerBusdBalance>=_price, "Not Enough BUSD available in buyer wallet");

       uint256 buyerApprovedAmount = approvedBusdAmountByBuyer();
       require(buyerApprovedAmount>=_price, "Not Enough BUSD Amount Approved by Buyer");

       IBEP20(BUSD).transferFrom(msg.sender, address(this), _price);
       _transfer(address(this), msg.sender, _amount);

       uint256 busdForLiquidity = _price.mul(100).div(5);
       busdInternalBalances["liquidity"] += busdForLiquidity;

       _price =  _price.sub(busdForLiquidity);

       uint256 d1daily =  _price.mul(1000).div(65);
       busdInternalBalances["d1daily"] += d1daily;

       uint256 d2daily =  _price.mul(1000).div(60);
       busdInternalBalances["d2daily"] += d2daily;       

       uint256 m1daily =  _price.mul(1000).div(100);
       busdInternalBalances["m1daily"] += m1daily; 
    
       uint256 remainingAmount = _price.sub(d1daily).sub(d2daily).sub(m1daily);
       busdInternalBalances["busdpool"] += remainingAmount;

   }


    function dailyInfusionForStaking() public 
    {
        if(totalInfusedTokens>=36500000 * 10**18) { return; }
        uint256 span = (block.timestamp-lastStakingTokenInfusionTimestamp).div(86400);
        uint256 amount =  span * 100000 * 10**18;
        if(amount==0) {return;}

        if(tokenInternalBalances["forsell"]<amount) { return; }

        tokenInternalBalances["forsell"] -= amount;

        uint256 forTopSponsorPool = amount.mul(100).div(3);
        uint256 forInsurancePool = amount.mul(100).div(3);
        uint256 forStakingPool =  amount.sub(forTopSponsorPool).sub(forInsurancePool);
        tokenInternalBalances["topsponsorpool"]  += forTopSponsorPool;
        tokenInternalBalances["insurancepool"]  += forInsurancePool;
        tokenInternalBalances["stakingpool"]  += forStakingPool;
        totalInfusedTokens  += amount; 
        lastStakingTokenInfusionTimestamp += span.add(86400);

    }

    /// @notice forsell, liquidity,  topsponsorpool, insurancepool, stakingpool
    function tokenInternalBalanceOf(string memory _head) public view returns(uint256)
    {
        return tokenInternalBalances[_head];
    }

    /// @notice busdpool, liquidity,  d1daily, d2daily, m1daily
    function busdInternalBalanceOf(string memory _head) public view returns(uint256)
    {
        return busdInternalBalances[_head];
    }


    // ---------- STAKES ----------

    uint256 minStakeAmount = 500**_decimals; //50 busd
    mapping(address => bool) internal consent; 
    
    //    Amount should be in Cordia tokens.
    //    Minimum tokens should be 'minStakeAmount'.
    //    This function can only check that staking is possible or not.
    function canStake(uint256 _stakeAmount, address account) public view returns (bool b)
    {
        if(balanceOf(account) > _stakeAmount && stakingOpen && stakes[account] == 0  && _stakeAmount>minStakeAmount)
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    // To check that given address is stake holder or not. 
    function isStakeHolder(address _address) public view returns(bool, uint256)
    {
        for(uint256 s = 0; s < stakeholders.length; s++) //s for serial and serial start here from zero. 
        {
            if(_address == stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }


    // Internal function that add and address to stake holders array
    function addStakeHolder(address _stakeHolder, uint256 _stakeAmount) private
    {
        (bool _isStakeHolder, ) = isStakeHolder(_stakeHolder);
        if(!_isStakeHolder) { stakeholders.push(_stakeHolder); }
        stakingTimestamp[_stakeHolder] = block.timestamp;
        stakes[_stakeHolder] = _stakeAmount;
    }


    //Amount should be in Codia Token
    function createStake(uint256 _amount) external
    {
        bool _canStake = canStake(_amount, msg.sender);
        require(_canStake, "Cannot Stake for some reason.");
        _transferTokens(msg.sender, address(this), _amount);
        addStakeHolder(msg.sender, _amount);

        uint256 forTopSponsorPool = _amount.mul(100).div(3);
        uint256 forInsurancePool = _amount.mul(100).div(3);
        uint256 forStakingPool =  _amount.sub(forTopSponsorPool).sub(forInsurancePool);

        tokenInternalBalances["topsponsorpool"]  += forTopSponsorPool;
        tokenInternalBalances["insurancepool"]  += forInsurancePool;
        tokenInternalBalances["stakingpool"]  += forStakingPool;
    }


    function stakeOf(address _stakeHolder) public view returns(uint256) 
    {
        return stakes[_stakeHolder];
    }


    function totalStakes()   public view returns(uint256)
    {
        return tokenInternalBalances["stakingpool"];
    }


    function removeStakeholder(address _stakeHolder) private
    {
        (bool _isStakeHolder, uint256 s) = isStakeHolder(_stakeHolder);
        if(_isStakeHolder)
        {
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
            stakingTimestamp[_stakeHolder] = 0;
            stakes[_stakeHolder] = 0;
        } 
    }



    function calculateReward(address _stakeHolder) public view returns(uint256, uint256)
    {
        uint256 stakedAmount = stakes[_stakeHolder];
        if(stakedAmount==0) { return (0, 0); }

        uint256 _stakingTimestamp =  stakingTimestamp[_stakeHolder];
        if(_stakingTimestamp==0) {return (0, 0); }

        uint256 span = block.timestamp-_stakingTimestamp;
        uint256 _days = span/oneDaySeconds;

        if(_days<initialPd) {return (0, _days); }

        if(_days>400) { _days=400; }

        uint256 _reward = stakedAmount.mul(_days).mul(75).div(10000);

        uint256 _alreadyWithDrawn = holderAlreadyWithDrawn[_stakeHolder];

       if(_alreadyWithDrawn >= stakedAmount.mul(3))
       {
            _reward = 0;
       }

       else
       {
           _reward = _reward.sub(_alreadyWithDrawn);
       }
        uint256 rewardInTokens =  _reward*tokensPerBusd;
        return (rewardInTokens, _days);
    }

    /// @notice Reward available to withdraw in Cordia token
    function rewardOf(address _stakeHolder) public view returns(uint256)
    {
        (uint256 reward,) = calculateReward(_stakeHolder);
        return reward;
    }

    /// @notice Reward Already withdrawan in Cordia token
    function rewardAlreadyWithDrawn(address _stakeHolder) public view returns(uint256)
    {
        uint256 reward = holderAlreadyWithDrawn[_stakeHolder];
        return (reward*tokensPerBusd);
    }

     
    function _withdrawReward(address _stakeHolder)  internal 
    {
        (uint256 reward,) = calculateReward(_stakeHolder);
        if(reward==0) { return; }
        holderAlreadyWithDrawn[_stakeHolder] += reward;
        transfer(_stakeHolder, reward);
    }


    /// @notice To withdraw available reward 
    function claimReward() external 
    {
        (bool _isStakeHolder,) = isStakeHolder(msg.sender);
        require(_isStakeHolder, "You are not a stake holder");
        _withdrawReward(msg.sender);
    }



////------ REFFEREL BONOUS ------////

    mapping(address => uint256) private _bonuses;

    function releaseBonuses(address[] memory _recipients, uint256[] memory _amount) public onlyOwner
    {   
        uint256 totalBonus = 0;

        for (uint i = 0; i <  _amount.length; i++) 
        {
            totalBonus +=  _amount[i];
        } 

        require(tokenInternalBalances["stakingpool"]>=totalBonus, "Insufficient tokens in staking pool");

        for (uint i = 0; i < _recipients.length; i++) 
        {
            _bonuses[_recipients[i]] += _amount[i];
        } 
    }


    function withdrawBonus() public 
    {
        uint256 amount = _bonuses[msg.sender];
       transferFrom(address(this), msg.sender, amount);
        _bonuses[msg.sender] = 0;
    }

    function bonusOf(address account) public view returns (uint256)
    {
        uint256 amount = _bonuses[account];
        return amount;
    }





   ////----- DAILY WITHDRAWAL ---- ////

    function sponsorsDailyWithdrawal() public 
    {
        require(busdInternalBalances["d1daily"]>0, "Balance must be more than zero.");

        uint256 d1Balance = busdInternalBalances["d1daily"];
        IBEP20(BUSD).transfer(getD1Wallet(), d1Balance);
        busdInternalBalances["d1daily"] = 0;

        uint256 d2Balance = busdInternalBalances["d2daily"];
        IBEP20(BUSD).transfer(getD2Wallet(), d2Balance);
        busdInternalBalances["d2daily"] = 0;

        uint256 m1Balance = busdInternalBalances["d1daily"];
        IBEP20(BUSD).transfer(getM1Wallet(), m1Balance);
        busdInternalBalances["m1daily"] = 0;

    }


    ////----- OCCASIONAL WITHDRAWAL ---- ////


    uint256 occWithdrawalAmount = 0;
    
    modifier onlySponsor() 
    {
        address _address = _msgSender();
        bool isCorrectWallet = (_address==getD1Wallet() || _address==getD2Wallet() || _address==getM1Wallet() || _address==getM2Wallet() || _address==getM3Wallet() || _address==owner());
        require(isCorrectWallet, "Sponsor: Caller is not the sponsor");
        _;
    }


    function initOccassionalWithDrawal(uint256 _amount) public onlySponsor 
    {
        require(occWithdrawalAmount>0, "Amount must be greater than 0.");
        uint256 sudtPoolBalance = busdInternalBalances["busdpool"];
        require(sudtPoolBalance>=_amount, "Amount exceeding available UST Balance inside USTD Pool");
        occWithdrawalAmount = _amount;
    }


    function resetOccassionalWithDrawal() public onlyOwner 
    {
        for(uint i=0; i<sponsors.length; i++)
        {
            consent[sponsors[i]] = false;
        }
        occWithdrawalAmount = 0;
    }



    function agreeOccassionalWithdrawal() public onlySponsor
    {
        require(occWithdrawalAmount>0, "No withdrawal is initiated.");
        address caller = msg.sender;
        consent[caller] = true;      
    }


    function areAllAgreeForOccassionalWithdrawal() public view returns(bool)
    {
        bool resp = true;
        for(uint i=0; i<sponsors.length; i++)
        {
            if(!consent[sponsors[i]])
            {
                resp = false;
                break;
            }
        }
        return resp;
    }



    function completeOccasionalWithdrawal() public 
    {

        bool b = areAllAgreeForOccassionalWithdrawal(); 
        require(b || msg.sender==getAdminWallet(), "All are not yet agree to withdraw BUSD");

        uint256 d1Share = occWithdrawalAmount.mul(1000).div(125);
        IBEP20(BUSD).transfer(getD1Wallet(), d1Share);

        uint256 d2Share = occWithdrawalAmount.mul(1000).div(125);
        IBEP20(BUSD).transfer(getD2Wallet(), d2Share);

        uint256 m1Share = occWithdrawalAmount.mul(1000).div(300);
        IBEP20(BUSD).transfer(getM1Wallet(), m1Share);

        uint256 m2Share = occWithdrawalAmount.mul(1000).div(300);
        IBEP20(BUSD).transfer(getM2Wallet(), m2Share);

        uint256 m3Share = occWithdrawalAmount.mul(1000).div(150);
        IBEP20(BUSD).transfer(getM2Wallet(), m3Share);

        resetOccassionalWithDrawal();

    } 


    event WithdrawBusdForLiquidity(address to, uint256 amount, uint256 timestamp);
    function withdrawBusdForLiquidity(uint256 _amount) public onlyOwner
    {
        require(busdInternalBalances["liquidity"]>_amount, "Exceeding BUSD Withdraw Limit for Liquidity"); 
        busdInternalBalances["liquidity"] -= _amount;
        _transfer(address(this), owner(), _amount);
        emit WithdrawBusdForLiquidity(owner(), _amount, block.timestamp);
    }



    event WithdrawalTokensForLiquidity(address to, uint256 amount, uint256 timestamp);
    function withdrawTokensForLiquidity(uint256 _amount) public onlyOwner
    {
        require(tokenInternalBalances["liquidity"]>_amount, "Exceeding Tokens Withdraw Limit for Liquidity");
        tokenInternalBalances["liquidity"] -= _amount;
        _transfer(address(this), owner(), _amount);
        emit WithdrawalTokensForLiquidity(owner(), _amount, block.timestamp);
    }


}
