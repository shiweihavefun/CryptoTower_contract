pragma solidity ^0.4.23;
import './utils/SafeMath.sol';
import './utils/Ownable.sol';
import './utils/ECRecovery.sol';
import './CKingCal.sol';

contract CKing is Ownable {
  using SafeMath for *;
  using CKingCal for uint256;
  using ECRecovery for bytes32;

  string constant public name = "CKing";
  string constant public symbol = "CK";

  // time constants;
  uint256 constant private timeInit = 1 hours; // 600; // 2 week
  uint256 constant private timeInc = 30 seconds; //60 //
  uint256 constant private timeMax = 5 minutes; // 300

  // profit distribution parameters
  uint256 constant private fixRet = 36;
  uint256 constant private extraRet = 9;
  uint256 constant private affRet = 10;
  uint256 constant private gamePrize = 20;
  uint256 constant private groupPrize = 15;
  uint256 constant private devTeam = 10;

  // player data
  struct Player {
    address addr; // player address
    bytes32 name; // playerName
    uint256 aff;  // affliliate vault
    uint256 affId; // affiliate id who referered u
    uint256 hretKeys; // number of high return keys
    uint256 mretKeys; // number of medium return keys
    uint256 lretKeys; // number of low return keys
    uint256 eth;      // total eth spend for the keys
    uint256 ethWithdraw; // earning withdrawed by user
  }

  mapping(uint256 => Player) public players; // player data
  mapping(address => uint) public addrXpId; // player address => pId
  mapping(bytes32 => uint256) public nameXpId; // player name => pId
  mapping(bytes32 => bool) public checks; // whether the withdraw check has been claimed
  uint public playerNum = 0;

  // game info
  uint256 public totalEther;     // total key sale revenue
  uint256 public totalKeys;      // total number of keys.
  uint256 private constant minPay = 1000000000; // minimum pay to buy keys or deposit in game;
  uint256 public totalCommPot;   // total ether going to be distributed
  uint256 private keysForGame;    // keys belongs to the game for profit distribution
  uint256 private gamePot;        // ether need to be distributed based on the side chain game
  uint256 private gameWithdrawed; // ether already been withdrawn from game vault
  uint256 public endTime;        // main game end time
  address private gameVault;
  address private teamVault;


  uint private stageId = 1;   // stageId start 1
  uint private constant groupPrizeStartAt = 2000000000000000000000000; // 1000000000000000000000;
  uint private constant groupPrizeStageGap = 100000000000000000000000; // 100000000000000000000
  mapping(uint => mapping(uint => uint)) public stageInfo; // stageId => pID => keys purchased in this stage

  // admin params
  uint256 private startTime;  // admin set start
  uint256 constant private coolDownTime = 5 minutes; // 24 hours;  // team is able to withdraw fund 24 hours after game end.

  modifier isGameActive() {
    uint _now = now;
    require(_now > startTime && _now < endTime);
    _;
  }

  // events
  event BuyKey(uint indexed _pID, uint _affId, uint _keyType, uint _keyAmount);
  event EarningWithdraw(uint indexed _pID, address _addr, uint _amount);
  event GameWithdraw(bytes _sign, uint _pID, address _addr, uint _amount);


  constructor(address _gameVault, address _teamVault) public {
    gameVault = _gameVault;
    teamVault = _teamVault;
  }

  function teamWithdraw() public {
    require(msg.sender == teamVault);
    uint256 _now = now;
    if(_now > endTime.add(coolDownTime)) {
      // withdraw all remaining balance to the team. if user does not claim his reward within coolDown period. they need to contact the dev team
      // for his game reward.
      uint amount = address(this).balance;
      teamVault.transfer(amount);
    }
  }

  function gameWithdrawByAdmin(uint256 _pID, uint256 _amount) public {
    require(msg.sender == gameVault); // only game vault can withdraw money for player

    uint _totalGamePot = getTotalGamePot();
    require(gameWithdrawed.add(_amount) < _totalGamePot); // this should always be true, otherwise someone must have issued wrong check. big problem
    gameWithdrawed  = gameWithdrawed.add(_amount);      // update gamewithdrawed

    address _to = players[_pID].addr;
    _to.transfer(_amount);
    emit GameWithdraw("0x0", _pID, _to, _amount);
  }

  function gameWithdraw(bytes memory _sign, uint256 _pID, uint256 _amount, uint _expire, uint256 _nonce) public {
    require(now < _expire);  // player need to claim the check before expire date, otherwise need to apply for another check.
    bytes32 _paramHash = getParamHash(_pID, _amount, _expire, _nonce);
    require(checks[_paramHash] == false); // the check must not been claimed yet;
    address _from = _paramHash.recover(_sign);

    require(_from == gameVault);    // only game vault can withdraw money for player

    uint _totalGamePot = getTotalGamePot();
    require(gameWithdrawed.add(_amount) < _totalGamePot); // this should always be true, otherwise someone must have issued wrong check. big problem
    gameWithdrawed  = gameWithdrawed.add(_amount);      // update gamewithdrawed

    address _to = players[_pID].addr;
    _to.transfer(_amount);
    checks[_paramHash] = true; // this check has been claimed;
    emit GameWithdraw(_sign, _pID, _to, _amount);
  }

  function getParamHash(uint256 _pID, uint256 _amount, uint _expire, uint256 _nonce) public pure returns (bytes32) {
    return keccak256(_pID, _amount, _expire, _nonce);
  }

  function startGame() onlyOwner public {
    startTime = now;
    endTime = startTime.add(timeInit);
  }

  function updateTimer(uint256 _keys) private {
    uint256 _now = now;
    uint256 _newTime;

    if(endTime.sub(_now) < timeMax) {
        _newTime = ((_keys) / (1000000000000000000)).mul(timeInc).add(endTime);
        if(_newTime.sub(_now) > timeMax) {
            _newTime = _now.add(timeMax);
        }
        endTime = _newTime;
    }
  }

  function buyByAddress(uint256 _affId, uint _keyType) payable isGameActive public {
    uint _pID = addrXpId[msg.sender];
    if(_pID == 0) { // player not exist yet. create one
      playerNum = playerNum + 1;
      Player memory p;
      p.addr = msg.sender;
      p.affId = _affId;
      players[playerNum] = p;
      _pID = playerNum;
      addrXpId[msg.sender] = _pID;
    }
    buy(_pID, msg.value, _affId, _keyType);
  }

  function buyFromVault(uint _amount, uint256 _affId, uint _keyType) public isGameActive  {
    uint _pID = addrXpId[msg.sender];
    uint _earning = getPlayerEarning(_pID);
    uint _newEthWithdraw = _amount.add(players[_pID].ethWithdraw);
    require(_newEthWithdraw < _earning); // withdraw amount cannot bigger than earning
    players[_pID].ethWithdraw = _newEthWithdraw; // update player withdraw
    buy(_pID, _amount, _affId, _keyType);
  }

  function getKeyPrice(uint _keyAmount) public view returns(uint256) {
    if(now > startTime) {
      return totalKeys.add(_keyAmount).ethRec(_keyAmount);
    } else {
      return (75000000000000);
    }
  }

  function buy(uint256 _pID, uint256 _eth, uint256 _affId, uint _keyType) private {
    if (_eth > minPay) { // bigger than minimum pay
      players[_pID].eth = _eth.add(players[_pID].eth);
      uint _keys = totalEther.keysRec(_eth);
      //bought at least 1 whole key
      if(_keys >= 1000000000000000000) {
        updateTimer(_keys);
      }

      //update total ether and total keys
      totalEther = totalEther.add(_eth);
      totalKeys = totalKeys.add(_keys);
      // update game portion
      uint256 _game = _eth.mul(gamePrize).div(100);
      gamePot = _game.add(gamePot);


      // update player keys and keysForGame
      if(_keyType == 1) { // high return key
        players[_pID].hretKeys  = _keys.add(players[_pID].hretKeys);
      } else if (_keyType == 2) {
        players[_pID].mretKeys = _keys.add(players[_pID].mretKeys);
        keysForGame = keysForGame.add(_keys.mul(extraRet).div(fixRet+extraRet));
      } else if (_keyType == 3) {
        players[_pID].lretKeys = _keys.add(players[_pID].lretKeys);
        keysForGame = keysForGame.add(_keys);
      }
      //update affliliate gain
      if(_affId != 0 && _affId != _pID) { // udate players
          uint256 _aff = _eth.mul(affRet).div(100);
          players[_affId].aff = _aff.add(players[_affId].aff);
          totalCommPot = (_eth.mul(fixRet+extraRet).div(100)).add(totalCommPot);
      } else { // addId == 0 or _affId is self, put the fund into earnings per key
          totalCommPot = (_eth.mul(fixRet+extraRet+affRet).div(100)).add(totalCommPot);
      }
      // update stage info
      if(totalKeys > groupPrizeStartAt) {
        updateStageInfo(_pID, _keys);
      }
      emit BuyKey(_pID, _affId, _keyType, _keys);
    } else { // if contribute less than the minimum conntribution return to player aff vault
      players[_pID].aff = _eth.add(players[_pID].aff);
    }
  }

  function updateStageInfo(uint _pID, uint _keyAmount) private {
    uint _stageL = groupPrizeStartAt.add(groupPrizeStageGap.mul(stageId - 1));
    uint _stageH = groupPrizeStartAt.add(groupPrizeStageGap.mul(stageId));
    if(totalKeys > _stageH) { // game has been pushed to next stage
      stageId = (totalKeys.sub(groupPrizeStartAt)).div(groupPrizeStageGap) + 1;
      _keyAmount = (totalKeys.sub(groupPrizeStartAt)) % groupPrizeStageGap;
      stageInfo[stageId][_pID] = stageInfo[stageId][_pID].add(_keyAmount);
    } else {
      if(_keyAmount < totalKeys.sub(_stageL)) {
        stageInfo[stageId][_pID] = stageInfo[stageId][_pID].add(_keyAmount);
      } else {
        _keyAmount = totalKeys.sub(_stageL);
        stageInfo[stageId][_pID] = stageInfo[stageId][_pID].add(_keyAmount);
      }
    }
  }

  function withdrawEarning(uint256 _amount) public {
    address _addr = msg.sender;
    uint256 _pID = addrXpId[_addr];
    require(_pID != 0);  // player must exist

    uint _earning = getPlayerEarning(_pID);
    uint _remainingBalance = _earning.sub(players[_pID].ethWithdraw);
    if(_amount > 0) {
      require(_amount <= _remainingBalance);
    }else{
      _amount = _remainingBalance;
    }


    _addr.transfer(_amount);  // transfer remaining balance to
    players[_pID].ethWithdraw = players[_pID].ethWithdraw.add(_amount);
  }

  function getPlayerEarning(uint256 _pID) view public returns (uint256) {
    Player memory p = players[_pID];
    uint _gain = totalCommPot.mul(p.hretKeys.add(p.mretKeys.mul(fixRet).div(fixRet+extraRet))).div(totalKeys);
    uint _total = _gain.add(p.aff);
    _total = getWinnerPrize(_pID).add(_total);
    return _total;
  }

  function getPlayerWithdrawEarning(uint _pid) public view returns(uint){
    uint _earning = getPlayerEarning(_pid);
    return _earning.sub(players[_pid].ethWithdraw);
  }

  function getWinnerPrize(uint256 _pID) view public returns (uint256) {
    uint _keys;
    uint _pKeys;
    if(now < endTime) {
      return 0;
    } else if(totalKeys > groupPrizeStartAt) { // keys in the winner stage share the group prize
      _keys = totalKeys.sub(groupPrizeStartAt.add(groupPrizeStageGap.mul(stageId - 1)));
      _pKeys = stageInfo[stageId][_pID];
      return totalEther.mul(groupPrize).div(100).mul(_pKeys).div(_keys);
    } else { // totalkeys does not meet the minimum group prize criteria, all keys share the group prize
      Player memory p = players[_pID];
      _pKeys = p.hretKeys.add(p.mretKeys).add(p.lretKeys);
      return totalEther.mul(groupPrize).div(100).mul(_pKeys).div(totalKeys);
    }
  }

  function getWinningStageInfo() view public returns (uint256 _stageId, uint256 _keys, uint256 _amount) {
    _amount = totalEther.mul(groupPrize).div(100);
    if(totalKeys < groupPrizeStartAt) { // group prize is not activate yet
      return (0, totalKeys, _amount);
    } else {
      _stageId = stageId;
      _keys = totalKeys.sub(groupPrizeStartAt.add(groupPrizeStageGap.mul(stageId - 1)));
      return (_stageId, _keys, _amount);
    }
  }

  function getTotalGamePot() view public returns (uint256) {
    uint _gain = totalCommPot.mul(keysForGame).div(totalKeys);
    uint _total = _gain.add(gamePot);
    return _total;
  }

}
