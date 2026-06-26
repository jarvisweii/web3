// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * 1. ✅ 创建一个名为Voting的合约，包含以下功能：
 * 一个mapping来存储候选人的得票数
 * 一个vote函数，允许用户投票给某个候选人
 * 一个getVotes函数，返回某个候选人的得票数
 * 一个resetVotes函数，重置所有候选人的得票数
 */

contract Voting {
    mapping(address => uint256) public ticketCount;
    address[] public candidates;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not an owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function vote(address user) public {
        require(user != address(0), "Invalid address");
        if (ticketCount[user] == 0) {
            candidates.push(user);
        }
        ticketCount[user]++;
    }

    function getVotes(address user) public view returns (uint256) {
        require(user != address(0), "Invalid address");
        return ticketCount[user];
    }

    function resetVotes() public onlyOwner {
        uint256 count = candidates.length;
        for (uint i = 0; i < count; i++) {
            delete ticketCount[candidates[i]];
        }
        delete candidates;
    }
}
