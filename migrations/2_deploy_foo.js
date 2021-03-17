const FooToken = artifacts.require("FOOToken");

module.exports = function (deployer) {
  deployer.deploy(FooToken);
};
