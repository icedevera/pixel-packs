import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const createPixelPack: DeployFunction = async function ({
  deployments,
  ethers,
  getChainId,
}: HardhatRuntimeEnvironment) {
  const { get, log } = deployments;
  const chainId = await getChainId();

  const accounts = await ethers.getSigners();
  const signer = accounts[0];

  const PixelPackFactoryContract = await ethers.getContractFactory(
    "PixelPackFactory"
  );
  const PixelPackFactory = await get("PixelPackFactory");
  const pixelPackFactory = new ethers.Contract(
    PixelPackFactory.address,
    PixelPackFactoryContract.interface,
    signer
  );

  log(`Generating Pixel Pack...`);
  const creation_tx = await pixelPackFactory.generatePixelPack();
  const receipt = await creation_tx.wait(1);
  const tokenId = receipt.events[3].topics[2];
  log(`NFT created with token number ${tokenId}`);

  log("Awaiting response from ChainLink VRF");

  if (chainId === "31337") {
    log("Detected local chain configuration.");
    log("Mocking VRFCoordinator random number and callback...");
    const VRFCoordinatorMock = await deployments.get("VRFCoordinatorMock");
    const vrfCoordinator = await ethers.getContractAt(
      "VRFCoordinatorMock",
      VRFCoordinatorMock.address,
      signer
    );
    const vrf_tx = await vrfCoordinator.callBackWithRandomness(
      receipt.events[3].topics[1],
      Math.floor(Math.random() * 100000),
      pixelPackFactory.address
    );
    await vrf_tx.wait(1);
    log("Random number mock completed.");
    log("Finishing NFT Mint...");
    const finish_tx = await pixelPackFactory.finishMint(tokenId);
    await finish_tx.wait(1);
    const tokenURI = await pixelPackFactory.tokenURI(tokenId);
    log(`NFT Minting Complete. You may view the tokenURI here: ${tokenURI}`);
  } else {
    // sloppy but it works
    await new Promise((r) => setTimeout(r, 180000));
    log("Finishing NFT Mint...");
    const finish_tx = pixelPackFactory.finsishMint(tokenId);
    await finish_tx.wait(1);
    const tokenURI = await pixelPackFactory.tokenURI(tokenId);
    log(`NFT Minting Complete. You may view the tokenURI here: ${tokenURI}`);
  }
};

export default createPixelPack;

createPixelPack.tags = ["all", "createonly"];
