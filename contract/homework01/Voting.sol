// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

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
