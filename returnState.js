var Web3 = require("web3");
var web3 = new Web3();
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

var owner = "0x78f7a44384c793bc773a0714b20652bec216a3f8"
var user = ["0x2a9b449e5884c0c0e64d9a4def768d18a830484c", "0x8214165b9320113c0f9b28ffe0b2412590272cf2"];

const fs = require('fs');
var abi = JSON.parse(fs.readFileSync("abi.txt","utf-8"));

//デプロイ済みのコントラクトのアドレス
var address = fs.readFileSync("address.txt","utf-8");
// var address = "0x07a6a12c23847bb23f09f5ff3999360c77de3d80";

const contract = new web3.eth.Contract(abi, address);

//template fin
contract.methods.preparationOwner(200,1000).send({from: owner}).on('error', function(error) { console.log(error);}).then(function(result){
  console.log('finish');
});
