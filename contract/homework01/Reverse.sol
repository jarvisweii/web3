// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * 2. ✅ 反转字符串 (Reverse String)
 *  题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"
 */
contract ReverseString {
    function reverseString(
        string calldata str
    ) external pure returns (string memory) {
        bytes calldata strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length);
        for (uint256 i = 0; i < strBytes.length; i++) {
            result[i] = strBytes[strBytes.length - 1 - i];
        }
        return string(result);
    }
}
