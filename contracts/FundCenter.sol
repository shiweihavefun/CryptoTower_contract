pragma solidity ^0.4.24;
import "./utils/ServerControl.sol";
// 用户提现由后台统一管理分配
// 并和私链交互，故而链上不记录用户充值提现的强关联
// 只是单纯的记录用户充值了多少钱、提现了多少钱即可。
contract FundCenter is ServerControl {

    event BalanceRecharge(address indexed sender, uint256 amount, uint64 evented_at); // 充值
    event BalanceWithdraw(address indexed sender, uint256 amount, bytes txHash, uint64 evented_at); //提现

    uint lowestRecharge = 0 ether; // 最低充值金额
    uint lowestWithdraw = 0 ether; //最低提现金额
    bool enable = true;

    mapping(address => uint) public recharges; // 充值记录
    mapping(address => uint) public withdraws; // 提现记录
    modifier onlyEnable {
        require(enable == true, "The service is closed.");
        _;
    }

    constructor () public {
        addServerAddress(msg.sender);
    }
    
    function recharge() public payable onlyEnable {
        require(msg.value >= lowestRecharge, "The minimum recharge amount does not meet the requirements.");
        recharges[msg.sender] += msg.value; // 纯记录用户一共充值了多少钱
        emit BalanceRecharge(msg.sender, msg.value, uint64(now));
    }

    // 服务端发起的提现
    function withdrawBalanceFromServer(address _to, uint _amount, bytes _txHash) public onlyServer onlyEnable {
        require(address(this).balance >= _amount, "Insufficient balance.");
        require(_amount >= lowestWithdraw, "Did not meet the minimum cash requirements.");
        _to.transfer(_amount);
        withdraws[_to] += _amount; // 纯记录用户一共提现了多少钱
        emit BalanceWithdraw(_to, _amount, _txHash, uint64(now));
    }

    // 提现到owner
    function withdrawBalanceFromAdmin(uint _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance.");
        owner.transfer(_amount);
    }

    function setLowestClaim(uint _lowestRecharge, uint _lowestWithdraw) public onlyOwner {
        lowestRecharge = _lowestRecharge;
        lowestWithdraw = _lowestWithdraw;
    }

    function setEnable(bool _enable) public onlyOwner {
        enable = _enable;
    }
}