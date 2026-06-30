// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";

import {NFTAuction} from "../contracts/NFTAuction.sol";
import {NFTAuctionV2} from "../contracts/NFTAuctionV2.sol";
import {MyNFT} from "../contracts/MyNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {MockOracle} from "../contracts/MockOracle.sol";
import {MockERC20} from "../contracts/MockERC20.sol";

contract NFTAuctionTest is Test {
    NFTAuction private auction;
    MyNFT private nft;
    MockERC20 private usdc;
    MockOracle private ethOracle;
    MockOracle private usdcOracle;
    ProxyAdmin private proxyAdminInstance;

    address private admin;
    address private proxyAdmin = address(2);
    address private seller = address(3);
    address private bidder1 = address(4);
    address private bidder2 = address(5);

    function setUp() public {
        admin = address(this);

        NFTAuction impl = new NFTAuction();
        bytes memory initData = abi.encodeCall(NFTAuction.initialize, 5);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            proxyAdmin,
            initData
        );

        auction = NFTAuction(address(proxy));

        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address proxyAdminAddress = address(
            uint160(uint256(vm.load(address(proxy), adminSlot)))
        );

        proxyAdminInstance = ProxyAdmin(proxyAdminAddress);

        nft = new MyNFT();
        usdc = new MockERC20("USDC", "USDC", 6, 1000000e6);

        ethOracle = new MockOracle(3000e8);
        usdcOracle = new MockOracle(1e8);

        vm.startPrank(admin);

        auction.setTokenOracles(address(0), address(ethOracle));
        auction.setTokenOracles(address(usdc), address(usdcOracle));
        vm.stopPrank();

        nft.mint(seller, 1);
        nft.mint(seller, 2);
        nft.mint(seller, 3);
        nft.mint(seller, 10);
        vm.startPrank(seller);
        nft.setApprovalForAll(address(auction), true);
        vm.stopPrank();
    }

    function test_getVersion() public view {
        assertEq(auction.getVersion(), "NFTAuction");
    }

    function test_toUsd() public view {
        uint256 ethPrice = auction.toUsd(address(0), 1 ether, 18);
        uint256 usdcPrice = auction.toUsd(address(usdc), 100e6, 6);

        console2.log("1 ETH = ", ethPrice);
        console2.log("100 USDC = ", usdcPrice);
        assertGt(ethPrice, 0);
        assertGt(usdcPrice, 0);
    }

    function test_initializeOnlyOnce() public {
        vm.startPrank(admin);
        vm.expectRevert();
        auction.initialize(5);
        vm.stopPrank();
    }

    function test_startOnlyAdmin() public {
        vm.startPrank(seller);
        vm.expectRevert("Only admin can call this function");
        auction.createAuction(
            seller,
            address(nft),
            1,
            1000,
            3600,
            address(usdc)
        );
        vm.stopPrank();
    }

    function test_startIncrementsAuctionId() public {
        vm.startPrank(admin);
        auction.createAuction(
            seller,
            address(nft),
            1,
            1000,
            3600,
            address(usdc)
        );
        assertEq(auction.auctionId(), 0);
        auction.createAuction(
            seller,
            address(nft),
            2,
            1000,
            3600,
            address(usdc)
        );
        assertEq(auction.auctionId(), 1);
        vm.stopPrank();
    }

    function test_startAuctionGtDuration() public {
        vm.startPrank(admin);
        auction.createAuction(seller, address(nft), 1, 1000, 30, address(usdc));
        uint256 currentAuctionId = auction.auctionId();

        vm.deal(seller, 1 ether);
        vm.warp(block.timestamp + 50);
        console2.log("current time", block.timestamp);
        vm.expectRevert("Seller cannot bid on their own auction");
        vm.startPrank(seller);
        auction.bid{value: 1 ether}(currentAuctionId, 1 ether);
        vm.stopPrank();
    }

    function test_bidLowerThanHighestBid() public {
        vm.startPrank(admin);
        auction.createAuction(seller, address(nft), 1, 1000, 30, address(usdc));
        uint256 currentAuctionId = auction.auctionId();

        vm.deal(bidder1, 2 ether);
        vm.deal(bidder2, 2 ether);

        vm.startPrank(bidder1);
        auction.bid{value: 2 ether}(currentAuctionId, 2 ether);

        vm.startPrank(bidder2);
        vm.expectRevert("Bid must meet the minimum increment");
        auction.bid{value: 1.2 ether}(currentAuctionId, 1.2 ether);
        vm.stopPrank();
    }

    function test_bidResult() public {
        vm.startPrank(admin);
        auction.createAuction(
            seller,
            address(nft),
            10,
            1000,
            3600,
            address(usdc)
        );
        uint256 currentAuctionId = auction.auctionId();

        vm.deal(seller, 20 ether);
        vm.deal(bidder1, 20 ether);
        vm.deal(bidder2, 20 ether);

        vm.startPrank(bidder1);
        auction.bid{value: 2 ether}(currentAuctionId, 2 ether);
        vm.startPrank(bidder2);
        auction.bid{value: 3 ether}(currentAuctionId, 3 ether);
        vm.startPrank(bidder1);
        auction.bid{value: 4 ether}(currentAuctionId, 4 ether);

        (, , , , uint256 highestBid, , address highestBidder, , , , ) = auction
            .auctions(currentAuctionId);

        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 4 ether);
        vm.stopPrank();
    }

    function test_upgrade() public {
        vm.startPrank(admin);
        auction.createAuction(
            seller,
            address(nft),
            10,
            1000,
            3600,
            address(usdc)
        );
        uint256 oldAuctionId = auction.auctionId();
        vm.stopPrank();

        NFTAuctionV2 newImpl = new NFTAuctionV2();

        vm.prank(proxyAdmin);
        proxyAdminInstance.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(auction))),
            address(newImpl),
            ""
        );

        NFTAuctionV2 upgradedAuction = NFTAuctionV2(payable(address(auction)));

        assertEq(upgradedAuction.auctionId(), oldAuctionId);
        assertEq(
            keccak256(abi.encodePacked(upgradedAuction.getVersion())),
            keccak256(abi.encodePacked("NFTAuctionV2"))
        );

        string memory newFunction = upgradedAuction.newFunction();
        assertEq(
            keccak256(abi.encodePacked(newFunction)),
            keccak256(abi.encodePacked("This is a new function"))
        );
    }

    function test_upgradeByNonAdmin() public {
        vm.startPrank(admin);
        auction.createAuction(
            seller,
            address(nft),
            10,
            1000,
            3600,
            address(usdc)
        );
        vm.stopPrank();

        NFTAuctionV2 newImpl = new NFTAuctionV2();

        vm.startPrank(seller);
        vm.expectRevert();
        proxyAdminInstance.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(auction))),
            address(newImpl),
            ""
        );
        vm.stopPrank();
    }

    function test_changeOracleAfterUpgrade() public {
        vm.startPrank(admin);
        auction.createAuction(
            seller,
            address(nft),
            10,
            1000,
            3600,
            address(usdc)
        );
        vm.stopPrank();

        MockOracle newEthOracle = new MockOracle(3000e8);

        NFTAuctionV2 newImpl = new NFTAuctionV2();

        vm.prank(proxyAdmin);
        proxyAdminInstance.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(auction))),
            address(newImpl),
            ""
        );

        NFTAuctionV2 upgradedAuction = NFTAuctionV2(payable(address(auction)));

        vm.startPrank(admin);
        upgradedAuction.setTokenOracles(address(0), address(newEthOracle));

        uint256 newPrice = upgradedAuction.getPriceUsd(address(0));
        assertEq(newPrice, 3000e8);

        vm.stopPrank();
    }
}
