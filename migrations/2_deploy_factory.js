const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const EIP712Forwarder = artifacts.require("EIP712Forwarder");

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    
    async function getNetID() {
      return new Promise(function(resolve, reject) {
        web3.providers.HttpProvider.prototype.sendAsync =
          web3.providers.HttpProvider.prototype.send;

        web3.currentProvider.sendAsync(
          {
            jsonrpc: "2.0",
            method: "net_version",
            params: [],
            id: 0
          },
          function(err, result) {
            if (err) {
              console.error(err.message);
              reject(err);
            } else {
              resolve(result.result);
            }
          }
        );
      });
    }
    setter = accounts[0];
    //deploy the facotry
    let factoryContract = await deployer.deploy(UniswapV2Factory, setter);
    console.log(await web3.eth.net.getId());
    
    
    
    let chainId = await getNetID();
    console.log(chainId);
    let try1 = web3.utils.toHex(chainId);
    let EIP712ForwarderContract = await deployer.deploy(EIP712Forwarder,try1);
  });
};
