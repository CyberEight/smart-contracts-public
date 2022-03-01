//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBotProtection {
    function protect(address receiver, uint256 amount) external;
}
