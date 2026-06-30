// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTAuction is ReentrancyGuard, Initializable {
    enum AuctionState {
        Active,
        Ended,
        Cancelled
    }

    struct Auction {
        IERC721 nft;
        uint256 nftId;
        address seller;
        uint256 startPriceInDollar; // 美元价格
        uint256 highestBid;
        uint256 highestBidInDollar;
        address highestBidder;
        address highestBidToken;
        IERC20 paymentToken;
        uint256 endTime;
        AuctionState state;
    }

    uint256 private _auctionCount;
    uint256 public auctionId;
    mapping(uint256 => Auction) public auctions;
    mapping(address => address) public tokenOracles;

    address public admin;
    uint256 public minBidIncrementPercent;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endTime
    );
    event AuctionBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount
    );
    event AuctionCancelled(uint256 indexed auctionId);
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _minBidIncrementPercent) public initializer {
        admin = msg.sender;
        minBidIncrementPercent = _minBidIncrementPercent;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function setTokenOracles(address token, address oracle) public onlyAdmin {
        require(oracle != address(0), "Oracle address cannot be zero");
        tokenOracles[token] = oracle;
    }

    function createAuction(
        address seller,
        address nft,
        uint256 nftId,
        uint256 startPriceInDollar,
        uint256 durationDays,
        address paymentToken
    ) public onlyAdmin {
        require(seller != address(0), "Seller address cannot be zero");
        require(nft != address(0), "NFT address cannot be zero");
        require(durationDays > 0, "Duration must be greater than 0");

        IERC721 nftContract = IERC721(nft);
        require(
            nftContract.ownerOf(nftId) == seller,
            "Seller must own the NFT"
        );

        auctionId = _auctionCount++;
        auctions[auctionId] = Auction({
            nft: nftContract,
            nftId: nftId,
            seller: seller,
            startPriceInDollar: startPriceInDollar,
            highestBid: 0,
            highestBidInDollar: 0,
            highestBidder: address(0),
            highestBidToken: address(0),
            paymentToken: IERC20(paymentToken),
            endTime: block.timestamp + (durationDays * 1 days),
            state: AuctionState.Active
        });

        nftContract.transferFrom(seller, address(this), nftId);

        emit AuctionCreated(
            auctionId,
            seller,
            nft,
            nftId,
            startPriceInDollar,
            auctions[auctionId].endTime
        );
    }

    function bid(uint256 auctionId_, uint256 amount) public payable {
        Auction storage auction = auctions[auctionId_];
        require(auction.state == AuctionState.Active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(
            msg.sender != auction.seller,
            "Seller cannot bid on their own auction"
        );

        uint256 bidPriceInDollar;
        // 是否是ETH出价
        if (msg.value > 0) {
            bidPriceInDollar = toUsd(address(0), msg.value, 18);
        } else {
            require(amount > 0, "ERC20 amount cannot less than 0");
            address paymentTokenAddress = address(auction.paymentToken);
            uint8 decimals = IERC20Metadata(paymentTokenAddress).decimals();
            bidPriceInDollar = toUsd(paymentTokenAddress, amount, decimals);
            // ERC20需要转到当前合约
            IERC20(paymentTokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            );
        }

        uint256 minBid;
        if (auction.highestBid == 0) {
            minBid = auction.startPriceInDollar;
        } else {
            minBid =
                auction.highestBidInDollar +
                ((auction.highestBidInDollar * minBidIncrementPercent) / 100);
        }

        require(
            bidPriceInDollar >= minBid,
            "Bid must meet the minimum increment"
        );

        // 如果有最高出价者，退还之前的出价
        if (
            auction.highestBidder != address(0) &&
            auction.highestBidder != msg.sender
        ) {
            uint256 refundAmount = auction.highestBid;
            if (refundAmount > 0) {
                if (auction.highestBidToken == address(0)) {
                    payable(auction.highestBidder).transfer(refundAmount);
                } else {
                    IERC20(address(auction.paymentToken)).transfer(
                        auction.highestBidder,
                        refundAmount
                    );
                }
            }
        }

        if (msg.value > 0) {
            auction.highestBid = msg.value;
            auction.highestBidToken = address(0);
        } else {
            auction.highestBid = amount;
            auction.highestBidToken = address(auction.paymentToken);
        }
        auction.highestBidder = msg.sender;
        auction.highestBidInDollar = bidPriceInDollar;

        emit AuctionBid(auctionId_, msg.sender, bidPriceInDollar);
    }

    function endAuction(uint256 auctionId_) public nonReentrant {
        Auction storage auction = auctions[auctionId_];
        require(auction.state == AuctionState.Active, "Auction is not active");
        require(block.timestamp >= auction.endTime, "Auction has not ended");

        auction.state = AuctionState.Ended;

        if (auction.highestBidder != address(0)) {
            auction.nft.transferFrom(
                address(this),
                auction.highestBidder,
                auction.nftId
            );

            if (auction.highestBidToken == address(0)) {
                // 如果是ETH出价
                payable(auction.seller).transfer(auction.highestBid);
            } else {
                // ERC20出价
                IERC20(auction.highestBidToken).transfer(
                    auction.seller,
                    auction.highestBid
                );
            }

            emit AuctionEnded(
                auctionId_,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            // 无人出价，直接把nft转给卖家
            auction.nft.transferFrom(
                address(this),
                auction.seller,
                auction.nftId
            );

            emit AuctionEnded(auctionId_, address(0), 0);
        }
    }

    function cancelAuction(uint256 auctionId_) public onlyAdmin {
        Auction storage auction = auctions[auctionId_];
        require(auction.state == AuctionState.Active, "Auction is not active");
        require(auction.highestBidder != address(0), "Auction cannot canncel");
        auction.state = AuctionState.Cancelled;

        auction.nft.transferFrom(
            address(this),
            auction.seller,
            auction.nftId
        );

        emit AuctionCancelled(auctionId_);
    }

    function getPriceUsd(address token) public view returns (uint256) {
        address oracle = tokenOracles[token];
        require(oracle != address(0), "Oracle not set for this token");
        AggregatorV3Interface priceFeed = AggregatorV3Interface(oracle);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function toUsd(
        address token,
        uint256 amount,
        uint256 decimals
    ) public view returns (uint256) {
        uint256 scale = 10 ** decimals;
        uint256 price = getPriceUsd(token);
        uint256 usd = (amount * price) / scale;
        return usd;
    }

    function getVersion() external pure virtual returns (string memory) {
        return "NFTAuction";
    }
}
