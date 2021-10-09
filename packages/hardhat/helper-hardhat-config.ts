export const networkConfig = {
  default: {
    name: "hardhat",
    keyHash:
      "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311",
    fee: "100000000000000000", // 0.1 LINK
    fundAmount: "1000000000000000000", // 0.1 LINK
  },
  "31337": {
    name: "localhost",
    keyHash:
      "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311",
    fee: "100000000000000000", // 0.1 LINK
    fundAmount: "1000000000000000000", // 0.1 LINK
  },
  "4": {
    name: "rinkeby",
    linkToken: "0x01BE23585060835E02B77ef475b0Cc51aA1e0709",
    vrfCoordinator: "0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B",
    keyHash:
      "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311",
    fee: "100000000000000000", // 0.1 LINK
    fundAmount: "1000000000000000000", // 0.1 LINK
  },
};

export const developmentChains = ["hardhat", "localhost"];

export const getNetworkIdFromName = async (networkIdName: string) => {
  for (const id in networkConfig) {
    if (networkConfig[id as "31337" | "4"].name == networkIdName) {
      return id;
    }
  }

  return null;
};

export default networkConfig;
