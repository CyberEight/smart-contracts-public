// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the array type
 */
library ArrayLib {
    function checkExists(address[] memory list, address addr)
        internal
        pure
        returns (bool isExist, uint256 index)
    {
        isExist = false;
        index = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == addr) {
                isExist = true;
                index = i;
                break;
            }
        }
    }

    function checkExists(uint256[] memory list, uint256 number)
        internal
        pure
        returns (bool isExist, uint256 index)
    {
        isExist = false;
        index = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == number) {
                isExist = true;
                index = i;
                break;
            }
        }
    }

    function checkExists(string[] memory list, string memory str)
        internal
        pure
        returns (bool isExist, uint256 index)
    {
        isExist = false;
        index = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (
                keccak256(abi.encodePacked(list[i])) ==
                keccak256(abi.encodePacked(str))
            ) {
                isExist = true;
                index = i;
                break;
            }
        }
    }

    function checkExists(bytes32[] memory list, bytes32 str)
        internal
        pure
        returns (bool isExist, uint256 index)
    {
        isExist = false;
        index = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (
                keccak256(abi.encodePacked(list[i])) ==
                keccak256(abi.encodePacked(str))
            ) {
                isExist = true;
                index = i;
                break;
            }
        }
    }

    function remove(address[] storage list, uint256 index) internal {
        _checkValidArray(list.length, index);
        list[index] = list[list.length - 1];
        list.pop();
    }

    function remove(uint256[] storage list, uint256 index) internal {
        _checkValidArray(list.length, index);
        list[index] = list[list.length - 1];
        list.pop();
    }

    function remove(string[] storage list, uint256 index) internal {
        _checkValidArray(list.length, index);
        list[index] = list[list.length - 1];
        list.pop();
    }

    function remove(bytes32[] storage list, uint256 index) internal {
        _checkValidArray(list.length, index);
        list[index] = list[list.length - 1];
        list.pop();
    }

    function removeUnchangedPosition(address[] storage list, uint256 index)
        internal
    {
        _checkValidArray(list.length, index);
        for (uint256 i = index; i < list.length - 1; i++) {
            list[i] = list[i + 1];
        }
        list.pop();
    }

    function removeUnchangedPosition(uint256[] storage list, uint256 index)
        internal
    {
        _checkValidArray(list.length, index);
        for (uint256 i = index; i < list.length - 1; i++) {
            list[i] = list[i + 1];
        }
        list.pop();
    }

    function removeUnchangedPosition(string[] storage list, uint256 index)
        internal
    {
        _checkValidArray(list.length, index);
        for (uint256 i = index; i < list.length - 1; i++) {
            list[i] = list[i + 1];
        }
        list.pop();
    }

    function removeUnchangedPosition(bytes32[] storage list, uint256 index)
        internal
    {
        _checkValidArray(list.length, index);
        for (uint256 i = index; i < list.length - 1; i++) {
            list[i] = list[i + 1];
        }
        list.pop();
    }

    function _checkValidArray(uint256 _length, uint256 _index) private pure {
        require(
            _length > 0 && _index < _length,
            "Array Library: List and/or index is invalid"
        );
    }
}
