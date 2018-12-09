const fs = require('fs');
const config = require('../config');
const Cking = artifacts.require("CKing.sol");
const FundCenter = artifacts.require("FundCenter.sol");

const writeResultToConfigFile = function(network, result) {
  fs.writeFileSync("./deployResult.json", JSON.stringify(result));
  console.log("deployResult.json write finish");
}


module.exports = function(deployer, network) {
  deployer.then(async () => {
    const deployResult = config;

    await deployer.deploy(Cking, deployResult.gameVault.address, deployResult.teamVault.address);

    const CkingInstance = Cking.at(Cking.address);

    // await CkingInstance.startGame();

    // console.log('game started.');

    deployResult.Cking.address = Cking.address;

    await deployer.deploy(FundCenter)

    deployResult.FundCenter.address = FundCenter.address;

    return writeResultToConfigFile(network, deployResult);
  });
};
