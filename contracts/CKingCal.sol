pragma solidity ^0.4.24;
import './utils/SafeMath.sol';

library CKingCal {

  using SafeMath for *;
  /**
  * @dev calculates number of keys received given X eth
  * @param _curEth current amount of eth in contract
  * @param _newEth eth being spent
  * @return amount of ticket purchased
  */
  function keysRec(uint256 _curEth, uint256 _newEth)
    internal
    pure
    returns (uint256)
  {
    return(keys((_curEth).add(_newEth)).sub(keys(_curEth)));
  }

  /**
  * @dev calculates amount of eth received if you sold X keys
  * @param _curKeys current amount of keys that exist
  * @param _sellKeys amount of keys you wish to sell
  * @return amount of eth received
  */
  function ethRec(uint256 _curKeys, uint256 _sellKeys)
    internal
    pure
    returns (uint256)
  {
    return((eth(_curKeys)).sub(eth(_curKeys.sub(_sellKeys))));
  }

  /**
  * @dev calculates how many keys would exist with given an amount of eth
  * @param _eth total ether received.
  * @return number of keys that would exist
  */
  function keys(uint256 _eth)
    internal
    pure
    returns(uint256)
  {
      // sqrt((eth*1 eth* 312500000000000000000000000)+5624988281256103515625000000000000000000000000000000000000000000) - 74999921875000000000000000000000) / 15625000
      return ((((((_eth).mul(1000000000000000000)).mul(3125000000000000000000000)).add(562498828125610351562500000000000000000000000000000000000000)).sqrt()).sub(749999218750000000000000000000)) / (1562500);
  }

  /**
  * @dev calculates how much eth would be in contract given a number of keys
  * @param _keys number of keys "in contract"
  * @return eth that would exists
  */
  function eth(uint256 _keys)
    internal
    pure
    returns(uint256)
  {
    // (149999843750000*keys*1 eth) + 78125000 * keys * keys) /2 /(sq(1 ether))
    return ((781250).mul(_keys.sq()).add(((1499998437500).mul(_keys.mul(1000000000000000000))) / (2))) / ((1000000000000000000).sq());
  }

}
