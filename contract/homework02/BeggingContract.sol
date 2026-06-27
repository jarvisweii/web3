// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 *  1. 使用 Solidity 编写一个合约，允许用户向合约地址发送以太币。
 *  2. 记录每个捐赠者的地址和捐赠金额。
 *  3. 允许合约所有者提取所有捐赠的资金。
 */
contract BeggingContract {
    mapping(address => uint256) public userAmounts;
    address public owner;
    uint256 public deadline;
    address[3] public topDonors;
    uint256[3] public topAmounts;

    event Donation(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Invalid time");
        _;
    }

    constructor(uint256 duration) {
        require(duration > 0, "Duration is invalid");
        owner = msg.sender;
        deadline = block.timestamp + (duration * 1 days);
    }

    function donate() public payable beforeDeadline {
        require(msg.value > 0, "Invalid value");
        userAmounts[msg.sender] += msg.value;

        _updateRanking();

        emit Donation(msg.sender, msg.value);
    }

    function withdraw() public onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}(
            ""
        );
        require(success, "withdraw failed");
    }

    function getDonation(address user) public view returns (uint256) {
        require(user != address(0), "Invalid address");
        return userAmounts[user];
    }

    function _updateRanking() private {
        uint256 amount = userAmounts[msg.sender];

        // 检查msg.sender是否在排行榜中
        int256 pos = -1;
        for (uint i = 0; i < 3; i++) {
            if (topDonors[i] == msg.sender) {
                topAmounts[i] = amount;
                pos = int256(i);
                break;
            }
        }

        // 如果不存在，且金额超过第3，则替换第三
        if (pos < 0 && amount > topAmounts[2]) {
            topDonors[2] = msg.sender;
            topAmounts[2] = amount;
            pos = 2;
        }

        if (pos < 0) {
            return;
        }

        // 排序
        for (uint i = uint256(pos); i > 0; i--) {
            if (topAmounts[i] > topAmounts[i - 1]) {
                (topDonors[i], topDonors[i - 1]) = (
                    topDonors[i - 1],
                    topDonors[i]
                );
                (topAmounts[i], topAmounts[i - 1]) = (
                    topAmounts[i - 1],
                    topAmounts[i]
                );
            } else {
                break;
            }
        }
    }

    function getTop3Address() public view returns (address[3] memory) {
        return topDonors;
    }
}
