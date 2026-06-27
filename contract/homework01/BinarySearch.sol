// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * 6. ✅ 二分查找 (Binary Search)
 * 题目描述：在一个有序数组中查找目标值。
 */
contract BinarySearch {
    function binarySearch(
        int256[] calldata num,
        int256 target
    ) external pure returns (int256) {
        if (num.length == 0) return -1;

        int256 right = num.length - 1;
        int256 left = 0;

        while (left <= right) {
            int256 mid = left + (right - left) / 2;
            if (num[mid] == target) {
                return mid;
            }
            if (num[mid] < target) {
                left = mid + 1;
            } else {
                if (mid == 0) {
                    break;
                }
                right = mid - 1;
            }
        }

        return -1;
    }
}
