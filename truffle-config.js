const Web3 = require("web3");
const protocol = "http";
const ip = "localhost";

module.exports = {
  networks: {
    avax_avash: {
      provider: function () {
        return new Web3.providers.HttpProvider(
          `${protocol}://${ip}:9650/ext/bc/C/rpc`
        );
      },
      network_id: "*",
      gas: 8000000,
      gasPrice: 470000000000,
    },
    avax_ganache: {
      host: ip,
      port: 9650,
      network_id: "*",
      gas: 8000000,
      gasPrice: 20000000,
    },
    eth: {
      host: ip,
      port: 8545,
      network_id: "*",
      gas: 8000000,
      gasPrice: 20000000,
    },
  },
  compilers: {
    solc: {
      version: "0.6.4",
    },
  },
};
