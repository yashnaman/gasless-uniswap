const Migrations = artifacts.require("Migrations");

module.exports = async function(deployer) {
  deployer.deploy(Migrations);
  let latestBlock = await web3.eth.getBlock("latest");
    let now = latestBlock.timestamp;
    console.log(web3.utils.toHex(now+3600));
};
