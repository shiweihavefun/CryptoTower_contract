const HDWalletPKProvider = require('truffle-hdwallet-provider-privkey')

let rinkeby_url = "https://rinkeby.infura.io/HZ7akc0jwna5cI2GpRW8";
let mainnet_url = "https://mainnet.infura.io/Q88mOfCzwxDGjA8h5Rmb";


let provider;


function getPKProvider(rpcUrl) {
  if (!provider) {
    provider = new HDWalletPKProvider([require('fs').readFileSync("PrivateKey", "utf8").trim()], rpcUrl)
  }

  return provider
}
 
module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gas: 4712388,
      gasPrice: 10000000000,
      network_id: "*" // Match any network id
      },
    ganache: {
        host: "127.0.0.1",
        port: 7545,
        network_id: "*", // match any netowkr id
        gas: 4712388,
        gasPrice: 10000000000
    },
    rinkeby: {
        network_id: 4,
        provider: function() {
          return getPKProvider(rinkeby_url)
        },
        gas: 4712388,
        gasPrice: 10000000000
    }
  }
  
};
