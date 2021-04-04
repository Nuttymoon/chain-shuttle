const Web3 = require("web3");
const HDWallerProvider = require("@truffle/hdwallet-provider");
const protocol = "http";
const host = "localhost";

module.exports = {
  networks: {
    avax_avash: {
      provider: function () {
        return new Web3.providers.HttpProvider(
          `${protocol}://${host}:9650/ext/bc/C/rpc`
        );
      },
      network_id: "*",
      gas: 8000000,
      gasPrice: 470000000000,
    },
    avax_geth: {
      provider: function () {
        return new HDWallerProvider({
          mnemonic: {
            phrase:
              "upper smile pigeon prison include expect open update hub enrich shine devote",
          },
          numberOfAddresses: 10,
          providerOrUrl: `${protocol}://${host}:9650`,
        });
      },
      network_id: "*",
      gas: 8000000,
      gasPrice: 20000000,
    },
    eth: {
      provider: function () {
        return new HDWallerProvider({
          mnemonic: {
            phrase:
              "upper smile pigeon prison include expect open update hub enrich shine devote",
          },
          numberOfAddresses: 10,
          providerOrUrl: `${protocol}://${host}:8545`,
        });
      },
      network_id: "*",
      gas: 8000000,
      gasPrice: 20000000,
    },
  },
  compilers: {
    solc: {
      version: "^0.8.0",
    },
  },
};
