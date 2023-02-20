// SPDX-License-Identifier: Unlicened
pragma solidity 0.8.17;

contract EthDoubler 
{
    address public owner;
    constructor () 
    {
        owner = msg.sender;
    }
    
    address[] public _investors;
    mapping(address=>uint256) public _investorsAmount;

    event EthReceipt(uint256);
    event EthDisbursed(address, uint256);
    event FeePaid(address, uint256);

    uint256 public fee = 0;
    uint256 public collectedBalance = 0;
    uint public index = 0;
    

    function totalInvestors() public view returns(uint)
    {
      return _investors.length;
    }

    function checkAndDisbursEth() internal 
    {
        address _account = _investors[index];
        uint256 dueAmount = _investorsAmount[_account]*2;
        if(collectedBalance>dueAmount)
        {
          payable(_account).transfer(dueAmount);
          emit EthDisbursed(_account, dueAmount);
          collectedBalance -= dueAmount;
          payable(owner).transfer(fee);
          emit FeePaid(owner, fee);
          fee = 0;
          index++;
        }
    }

    uint256 public maxLimit = 1e17;

    function setMaxLimit(uint256 _newAmount) external returns(bool)
    {
      require(msg.sender==owner, "Only owner can change max limit");
      maxLimit = _newAmount;
      return true;
    } 

    receive() external payable 
    {
      require(msg.value<maxLimit, "Amount must be less than 0.1 eth");
      _investors.push(msg.sender);
      _investorsAmount[msg.sender] = msg.value;
      emit EthReceipt(msg.value);
      fee += ((msg.value)/10);
      collectedBalance += ((msg.value)*9/10);
      if(_investors.length>1)
      {
        checkAndDisbursEth();
      }
    }  

}
