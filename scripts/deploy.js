// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contract with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const RealEstateTokenization = await hre.ethers.getContractFactory("RealEstateTokenization");
  const contract = await RealEstateTokenization.deploy();

  await contract.deployed();

  console.log("RealEstateTokenization deployed at:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
