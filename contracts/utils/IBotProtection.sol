//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBotProtection {
    function protect(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}
