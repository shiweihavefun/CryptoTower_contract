pragma solidity ^0.4.24;
import "./Ownable.sol";

contract ServerControl is Ownable {
    event AddServerAddress(address contractAddress);
    event RemoveServerAddress(address contractAddress);
    mapping (address => bool) public serverAddressList;
    modifier onlyServer {
        require(serverAddressList[msg.sender], "Sponsor must be allowed.");
        _;
    }

    function addServerAddress(address _serverAddress) public onlyOwner {
        serverAddressList[_serverAddress] = true;
        emit AddServerAddress(_serverAddress);
    }

    function removeServerAddress(address _serverAddress) public onlyOwner {
        require(serverAddressList[_serverAddress], "The server address has been deleted.");
        serverAddressList[_serverAddress] = false;
        emit RemoveServerAddress(_serverAddress);
    }
}