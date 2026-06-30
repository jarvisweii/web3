import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import NFTAuctionModule from "./NFTAuctionProxyModule.js";

const nftAuctionUpgradeModule = buildModule("NFTAuctionUpgradeModule", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const { proxyAdmin, proxy } = m.useModule(NFTAuctionModule);

    const auctionV2 = m.contract("NFTAuctionV2");

    m.call(proxyAdmin, "upgradeAndCall", [proxy, auctionV2, "0x"], {
        from: proxyAdminOwner
    });

    const auction = m.contractAt("NFTAuctionV2", proxy, {
        id: "NFTAuctionV2AtProxy"
    });

    return { auction, proxyAdmin, proxy };
});

export default nftAuctionUpgradeModule;