import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const nftAuctionProxyModule = buildModule("NFTAuctionProxyModule", (m) => {

    const proxyAdminOwner = m.getAccount(0);
    const auctionImpl = m.contract("NFTAuction");
    const encodedFunctionCall = m.encodeFunctionCall(auctionImpl, "initialize", [5]);

    const proxy = m.contract("TransparentUpgradeableProxy", [
        auctionImpl,
        proxyAdminOwner,
        encodedFunctionCall
    ]);

    const proxyAdminAddress = m.readEventArgument(proxy, "AdminChanged", "newAdmin");

    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

    return { proxyAdmin, proxy };
});

const nftAuctionModule = buildModule("NFTAuctionModule", (m) => {
    const { proxy, proxyAdmin } = m.useModule(nftAuctionProxyModule);
    const auction = m.contractAt("NFTAuction", proxy);
    return { auction, proxy, proxyAdmin };
});

export default nftAuctionModule;