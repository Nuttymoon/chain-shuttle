const Web3 = require("web3");
const protocol = "http";
const ip = "localhost";
const port = 9650;

module.exports = {
  networks: {
    avax_local: {
      provider: function () {
        return new Web3.providers.HttpProvider(
          `${protocol}://${ip}:${port}/ext/bc/C/rpc`
        );
      },
      network_id: "*",
      gas: 3000000,
      gasPrice: 470000000000,
    },
    eth_local: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
    },
  },
  compilers: {
    solc: {
      version: "^0.7.0",
    },
  },
};
