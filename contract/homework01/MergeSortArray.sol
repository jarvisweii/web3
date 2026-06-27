// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * 5. ✅ 合并两个有序数组 (Merge Sorted Array)
 * 题目描述：将两个有序数组合并为一个有序数组。
 */
contract MergeSortedArray {
    function mergeSortedArray(
        uint256[] calldata a,
        uint256[] calldata b
    ) external pure returns (uint256[] memory) {
        uint256 aLen = a.length;
        uint256 bLen = b.length;
        uint256[] memory result = new uint256[](aLen + bLen);

        uint256 indexA = 0;
        uint256 indexB = 0;
        uint256 index = 0;
        while (indexA < aLen && indexB < bLen) {
            if (a[indexA] <= b[indexB]) {
                result[index++] = a[indexA++];
            } else {
                result[index++] = b[indexB++];
            }
        }
        while (indexA < aLen) {
            result[index++] = a[indexA++];
        }
        while (indexB < bLen) {
            result[index++] = b[indexB++];
        }

        return result;
    }
}
