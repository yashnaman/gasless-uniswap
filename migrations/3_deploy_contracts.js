const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const mDAI = artifacts.require("MDAI");
const mETH = artifacts.require("METH");
const m0x = artifacts.require("M0x");
const mBTC = artifacts.require("MBTC");
const MANA = artifacts.require("MANA");
const mUSDT = artifacts.require("MUSDT");
const UniswapV2Router01 = artifacts.require("UniswapV2Router01");
const EIP712Forwarder = artifacts.require("EIP712Forwarder");
//
module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    setter = accounts[0];
    //get the deployed  facotry
    let factoryContract = await UniswapV2Factory.deployed();
    let EIP712ForwarderContract = await EIP712Forwarder.deployed();
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
    function getAmountWithDecimals(_tokenAmount) {
      var decimals = web3.utils.toBN(18);
      var tokenAmount = web3.utils.toBN(_tokenAmount);
      var tokenAmountHex = tokenAmount.mul(web3.utils.toBN(10).pow(decimals));

      return web3.utils.toHex(tokenAmountHex);
    }

    let chainId = await getNetID();

    var initialSupply = getAmountWithDecimals(1000000);

    //deploy ERC20 contracts
    let mDAIContract = await deployer.deploy(mDAI, initialSupply, chainId);
    let mETHContract = await deployer.deploy(mETH, initialSupply, chainId);
    let m0XContract = await deployer.deploy(m0x, initialSupply, chainId);
    let MANAContract = await deployer.deploy(MANA, initialSupply, chainId);
    let mBTCContract = await deployer.deploy(mBTC, initialSupply, chainId);
    let mUSDTContract = await deployer.deploy(mUSDT, initialSupply, chainId);

    //deploy the router contracts
    let routerContract = await deployer.deploy(
      UniswapV2Router01,
      mETH.address,
      factoryContract.address,
      EIP712ForwarderContract.address
      // chainId
    );

    var liquidityAmount = getAmountWithDecimals(10000);

    var erc20 = [
      mDAIContract,
      mETHContract,
      m0XContract,
      MANAContract,
      mBTCContract,
      mUSDTContract
    ];
    let latestBlock = await web3.eth.getBlock("latest");
    let now = latestBlock.timestamp;
    console.log(now);
    
    let expiry = web3.utils.toHex(now + 3600);
	 var addresses = {
      "mDAI": mDAIContract.address,
      "mETH": mETHContract.address,
      "m0x": m0XContract.address,
      "MANA": MANAContract.address,
      "mBTC":mBTC.address,
      "mUSDT":mUSDT.address,
      "factoryAddress": factoryContract.address,
      "routerAddress": routerContract.address,
      "EIP712forwarderAddress":EIP712ForwarderContract.address
    }
    console.log(addresses);
    for (i = 0; i < 6; i++) {
      for (j = i + 1; j < 6; j++) {
        await erc20[i].approve(routerContract.address, liquidityAmount);
        await erc20[j].approve(routerContract.address, liquidityAmount);
        await routerContract.addLiquidity(
          erc20[i].address,
          erc20[j].address,
          liquidityAmount,
          liquidityAmount,
          liquidityAmount,
          liquidityAmount,
          setter,
          expiry
        );
      }
    }
    console.log("uidityDone");
    
    console.log((await factoryContract.allPairsLength()).toString());
    var swapAmount = getAmountWithDecimals(10);
    await MANAContract.approve(routerContract.address, swapAmount);
    var path = [MANAContract.address, mUSDTContract.address];

    let amountOutMin = await routerContract.getAmountsOut(swapAmount, path);
    let a = await mUSDTContract.balanceOf(setter);
    console.log(a.toString());
    await routerContract.swapExactTokensForTokens(
      swapAmount,
      web3.utils.toHex(amountOutMin[1]),
      path,
      setter,
      expiry
    );
     a = await mUSDTContract.balanceOf(setter);
    console.log(a.toString());
     addresses = {
      "mDAI": mDAIContract.address,
      "mETH": mETHContract.address,
      "m0x": m0XContract.address,
      "MANA": MANAContract.address,
      "mBTC":mBTC.address,
      "mUSDT":mUSDT.address,
      "factoryAddress": factoryContract.address,
      "routerAddress": routerContract.address,
      "EIP712forwarderAddress":EIP712ForwarderContract.address
    }
    let liquidityAmount1 = getAmountWithDecimals(100);
    let liquidityAmount2 = getAmountWithDecimals(200);
    await mUSDTContract.approve(routerContract.address, liquidityAmount1);
    await MANAContract.approve(routerContract.address, liquidityAmount2);
    let reserves = await routerContract.getReserves(mUSDTContract.address,MANAContract.address);
    console.log(reserves);
    let amountAmin = await routerContract.quote(liquidityAmount2,reserves[0],reserves[1]);
    let amountBmin = await routerContract.quote(liquidityAmount1,reserves[1],reserves[0]);
    console.log(amountAmin);
    
    routerContract.addLiquidity(mUSDTContract.address,MANAContract.address,liquidityAmount1,liquidityAmount2,amountAmin,amountBmin,setter,expiry);
  });
};
