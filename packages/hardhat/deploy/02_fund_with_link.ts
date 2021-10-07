import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { networkConfig, getNetworkIdFromName } from "../helper-hardhat-config";

const fundWithLink: DeployFunction = async function ({
  deployments,
  getChainId,
  ethers,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy, log, get } = deployments;
  const chainId = await getChainId();

  log("Funding contract with LINK...");
  const PixelPackFactory = await get("PixelPackFactory");

  const accounts = await ethers.getSigners();
  const signer = accounts[0];

  let linkTokenAddress;
  if (chainId === "31337") {
    const linkToken = await get("LinkToken");
    linkTokenAddress = linkToken.address;
  } else {
    linkTokenAddress = networkConfig[chainId as "4"].linkToken;
  }

  // fund with LINK
  let networkId = (await getNetworkIdFromName(network.name)) ?? "";
  const fundAmount = networkConfig[networkId as "31337"].fundAmount;
  const linkTokenContract = await ethers.getContractFactory("LinkToken");
  const linkToken = new ethers.Contract(
    linkTokenAddress,
    linkTokenContract.interface,
    signer
  );
  let fund_tx = await linkToken.transfer(PixelPackFactory.address, fundAmount);
  await fund_tx.wait(1);

  log("Funded contract with configured LINK amount");
};

export default fundWithLink;

fundWithLink.tags = ["all", "fundLink", "fundOnly"];
