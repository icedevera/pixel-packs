import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { networkConfig } from "../helper-hardhat-config";

const deployPixelPacks: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  getChainId,
}: HardhatRuntimeEnvironment) {
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  let linkTokenAddress, vrfCoordinatorAddress;
  const networkName = networkConfig[chainId as "31337" | "4"].name;

  if (chainId === "31337") {
    // means we are on a local chain so we deploy mocks
    const linkToken = await get("LinkToken");
    linkTokenAddress = linkToken.address;

    const vrfCoordinatorMock = await get("VRFCoordinatorMock");
    vrfCoordinatorAddress = vrfCoordinatorMock.address;
  } else {
    linkTokenAddress = networkConfig[chainId as "4"].linkToken;
    vrfCoordinatorAddress = networkConfig[chainId as "4"].vrfCoordinator;
  }

  const keyHash = networkConfig[chainId as "4"].keyHash;
  const fee = networkConfig[chainId as "4"].fee;

  let args = [
    vrfCoordinatorAddress,
    linkTokenAddress,
    keyHash,
    fee,
    // change these to test out the different possible attribute effects
    [
      1, // _darkAuraOdds
      1, // _lightAuraOdds
      1, // _darkStrokeOdds
      1, // _lightStrokeOdds
      1000, // _corruptOdds
      1000, // _nobleOdds
    ],
  ];

  log("---------------------------------------------------------------------");
  log(`Deploying PixelPackFactory to ${networkName}.`);
  const PixelPackFactory = await deploy("PixelPackFactory", {
    from: deployer,
    args: args,
    log: true,
  });
  log(`Succcesfully deployed PixelPackFactory to ${networkName}.`);

  log(
    `Verify with: \n yarn hardhat verify --network ${networkName} ${
      PixelPackFactory.address
    } ${args.toString().replace(/,/g, " ")}`
  );
};

export default deployPixelPacks;

deployPixelPacks.tags = ["all", "mockpxp", "pxponly", "fundlink"];
