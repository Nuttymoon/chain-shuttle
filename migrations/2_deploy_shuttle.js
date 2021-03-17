const ChainShuttle = artifacts.require("ChainShuttle");

module.exports = function (deployer) {
  deployer.deploy(ChainShuttle);
};
