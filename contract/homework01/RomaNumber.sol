// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * 3. ✅ 用 solidity 实现整数转罗马数字
 * 罗马数字包含以下七种字符: I， V， X， L，C，D 和 M。
 *
 * 字符          数值
 * I             1
 * V             5
 * X             10
 * L             50
 * C             100
 * D             500
 * M             1000
 * 例如， 罗马数字 2 写做 II ，即为两个并列的 1 。12 写做 XII ，即为 X + II 。 27 写做  XXVII, 即为 XX + V + II 。
 *
 * 通常情况下，罗马数字中小的数字在大的数字的右边。但也存在特例，例如 4 不写做 IIII，而是 IV。数字 1 在数字 5 的左边，所表示的数等于大数 5 减小数 1 得到的数值 4 。同样地，数字 9 表示为 IX。这个特殊的规则只适用于以下六种情况：
 *
 * I 可以放在 V (5) 和 X (10) 的左边，来表示 4 和 9。
 * X 可以放在 L (50) 和 C (100) 的左边，来表示 40 和 90。
 * C 可以放在 D (500) 和 M (1000) 的左边，来表示 400 和 900。
 * 给定一个罗马数字，将其转换成整数。
 */

contract RomaNumber {
    function convertToNum(
        string calldata number
    ) external pure returns (uint256) {
        bytes calldata s = bytes(number);
        uint256 result;
        for (uint i = 0; i < s.length; i++) {
            uint256 cur = _value(s[i]);
            if (i + 1 < s.length && cur < _value(s[i + 1])) {
                result += _value(s[i + 1]) - cur;
                i++;
            } else {
                result += cur;
            }
        }
        return result;
    }

    function _value(bytes1 c) private pure returns (uint256) {
        if (c == "I") return 1;
        if (c == "V") return 5;
        if (c == "X") return 10;
        if (c == "L") return 50;
        if (c == "C") return 100;
        if (c == "D") return 500;
        if (c == "M") return 1000;
        return 0;
    }

    function convertToRomaNum(
        uint256 number
    ) public pure returns (string memory) {
        require(number > 0 && number <= 3999, "Out of range");

        string[13] memory symbols = [
            "M",
            "CM",
            "D",
            "CD",
            "C",
            "XC",
            "L",
            "XL",
            "X",
            "IX",
            "V",
            "IV",
            "I"
        ];
        uint256[13] memory values = [
            uint256(1000),
            900,
            500,
            400,
            100,
            90,
            50,
            40,
            10,
            9,
            5,
            4,
            1
        ];

        string memory result;
        for (uint i = 0; i < values.length; i++) {
            while (number >= values[i]) {
                result = string.concat(result, symbols[i]);
                number -= values[i];
            }
        }
        return result;
    }
}
