import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const createPixelPack: DeployFunction = async function ({
  deployments,
  ethers,
  getChainId,
}: HardhatRuntimeEnvironment) {
  const { get, log } = deployments;
  const chainId = await getChainId();

  log(`Generating Pixel Pack...`);
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

  const creation_tx = pixelPackFactory.generatePixelPack({ gasLimit: 300000 });
  const receipt = creation_tx.wait(1);
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
      receipt.log[3].topics[1],
      69,
      pixelPackFactory.address
    );
    await vrf_tx.wait(1);
    log("Random number mock completed.");
    log("Finishing NFT Mint...");
    const finish_tx = pixelPackFactory.finsishMint(tokenId, {
      gasLimit: 2000000,
    });
    await finish_tx.wait(1);
    const tokenURI = pixelPackFactory.tokenURI(tokenId);
    log(`NFT Minting Complete. You may view the tokenURI here: ${tokenURI}`);
  } else {
    // sloppy but it works
    await new Promise((r) => setTimeout(r, 180000));
    log("Finishing NFT Mint...");
    const finish_tx = pixelPackFactory.finsishMint(tokenId, {
      gasLimit: 2000000,
    });
    await finish_tx.wait(1);
    const tokenURI = pixelPackFactory.tokenURI(tokenId);
    log(`NFT Minting Complete. You may view the tokenURI here: ${tokenURI}`);
  }
};

export default createPixelPack;

createPixelPack.tags = ["all", "createOnly"];