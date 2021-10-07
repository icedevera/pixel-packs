import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployMocks: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
}: HardhatRuntimeEnvironment) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  if (chainId === "31337") {
    log("Local network detected: Deploying mocks to local chain...");

    log("Deploying LinkToken to local chain...");
    const LinkToken = await deploy("LinkToken", { from: deployer, log: true });
    log("LinkToken Deployed!");

    log("Deploying VRFCoordinatorMock to local chain...");
    const VRFCoordinatorMock = await deploy("VRFCoordinatorMock", {
      from: deployer,
      log: true,
      args: [LinkToken.address],
    });
    log("VRFCoordinatorMock Deployed!");

    log("Mocks Deployed Successfully.");
  }
};

export default deployMocks;

deployMocks.tags = ["all", "mocks"];
