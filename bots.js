import ethers from 'ethers';
import dotenv from 'dotenv';
import logger from 'node-color-log';
import { pancakeswapABI } from './pancakeswap-abi.js';
import { lpABI } from './lp.js';
import request from 'request';

dotenv.config();

const data = {
  
  MATIC: process.env.MATIC_CONTRACT, //MATIC

  to_PURCHASE: process.env.TO_PURCHASE, // token that you will purchase 

  AMOUNT_OF_TOKEN: process.env.AMOUNT_OF_TOKEN, // how much you want to swap in token

  lprouter: process.env.LPROUTER, //PancakeSwap V2 router
  router: process.env.ROUTER, 

  recipient: process.env.YOUR_ADDRESS, //your wallet address,

  Slippage: process.env.SLIPPAGE, //in Percentage

  gasPrice: ethers.utils.parseUnits(`${process.env.GWEI}`, 'gwei'), //in gwei

  gasLimit: process.env.GAS_LIMIT, //at least 21000  
  
}


const rpc = process.env.RPC_NODE;

const mnemonic = process.env.YOUR_MNEMONIC;


let tokenIn = data.MATIC;
let tokenOut = data.to_PURCHASE;
let provider;

provider = new ethers.providers.JsonRpcProvider(rpc);


const wallet = new ethers.Wallet(mnemonic);
const account = wallet.connect(provider, mnemonic);


const router = new ethers.Contract(
  data.router,
  pancakeswapABI,
  account
);

const lp = new ethers.Contract(
  data.lprouter,
  lpABI,
  account
);

let TOKENBalance = 0;
let MATICBalance = 0;

let Tx = "";
let ExchangeAmount = "";
let isExchange = true;
let LPBalance=0;
let dexPrice=0;


const run = async () => {




  setInterval(() => {
    try{   
      getInitalBalance();
      
      if ( LPBalance>=0.1) {
          Dex();
      } else {
        Tx = "Not Enough Liquidity";
        ExchangeAmount = "None";        
        isExchange = false;
        history();

      }
    }catch(err ) {
        console.log(err);
        throw new Error(err);
      }
  }, 5000)
}

const history = () => {

  logger.bgColor(Tx.includes("http") ? "magenta" : "blue").log(`
  [${(new Date()).toLocaleTimeString()}]: 


  | ${isExchange ? "Exchanged" : "Skipped"}
  | MATIC(${MATICBalance}) 
  | TOKEN(${TOKENBalance}) 
  | Exchange Amount(${ExchangeAmount} MATIC) 
  | Transaction(${Tx}) 
  `)
}

let TOKENBNB = async () => {
  let Eu =  data.AMOUNT_OF_TOKEN;

  Eu = dexPrice > Eu ? Eu : dexPrice;
  

  try {
  const tx = await lp.sellDLY(10000);
    const receipt = await tx.wait();
    Tx = `https://polygonscan.com/tx/${receipt.logs[1].transactionHash}`;

    ExchangeAmount = Eu + " TOKEN";
    isExchange = true;

    history();
    // console.log(`Transaction receipt : https://polygonscan.com/tx/${receipt.logs[1].transactionHash}`);
    
  } catch (err) {
    console.log(err);
    Tx = "Transaction Fail. Network Connection Error";
    ExchangeAmount = "None";
    isExchange = false;


    history();

    run();
  }
}


async function getPrice(inputCurrency, outputCurrency) {
  try {
    const amounts = await router.getAmountsOut(ethers.utils.parseUnits('1', 18), [inputCurrency, outputCurrency]);
    return amounts[1].toString() / 1e18;
  } catch (error) {
    console.log(error);
    getPrice(inputCurrency, outputCurrency);
  }
}


const Dex = async () => {  
    if (TOKENBalance > 1) {
      await TOKENBNB();
    } else {
      Tx = "Not Enough TOKEN Balance";
      ExchangeAmount = "None";
      isExchange = false;     

      history();
    
  }
}


const getInitalBalance = async () => { 

  LPBalance = parseInt(await  provider.getBalance(data.lprouter)) / 1e18;
  MATICBalance = parseInt(await account.getBalance()) / 1e18;
  const erc = new ethers.Contract(
    data.to_PURCHASE,
    [{ "constant": true, "inputs": [{ "name": "_owner", "type": "address" }], "name": "balanceOf", "outputs": [{ "name": "balance", "type": "uint256" }], "payable": false, "type": "function" }],
    account
  );

  TOKENBalance = parseInt(await erc.balanceOf(data.recipient)) / 1e18;

  getPrice(tokenIn, tokenOut).then(price => {
    console.log("dexPrice ("+price+")");
    dexPrice=price*MATICBalance;
  });
  
  console.log("TokenBalance ("+TOKENBalance+")");
  console.log("MATICBalance ("+MATICBalance+")");
  console.log("LPBalance ("+LPBalance+")");

}
run();
