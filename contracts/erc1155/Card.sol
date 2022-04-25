// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/IEnums.sol";

contract CardContract is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC1155BurnableUpgradeable
{
    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => bool) private _operators;

    function initialize(address ownerAddress_) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();
        __ERC1155_init("");
        __ERC1155Burnable_init();

        OwnableUpgradeable.transferOwnership(ownerAddress_);
    }

    event Operator(address operator, bool isOperator);
    event Mint(address recipient, uint256 id, uint256 amount, bytes data);
    event MintBatch(
        address recipient,
        uint256[] ids,
        uint256[] amounts,
        bytes data
    );
    event Burn(address from, uint256 id, uint256 amount);
    event BurnBatch(address from, uint256[] ids, uint256[] amounts);

    modifier onlyOperator() {
        require(_operators[msg.sender], "Card: Sender is not operator");
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public whenNotPaused onlyOperator {
        require(id <= uint256(IEnums.Rarity.LEGEND), "ID is invalid");
        _mint(account, id, amount, data);
        emit Mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public whenNotPaused onlyOperator {
        for (uint256 i = 0; i < ids.length; i++) {
            require(ids[i] <= uint256(IEnums.Rarity.LEGEND), "ID is invalid");
        }
        _mintBatch(to, ids, amounts, data);
        emit MintBatch(to, ids, amounts, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override whenNotPaused {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override whenNotPaused {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public override whenNotPaused onlyOperator {
        super.burn(from, id, amount);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual override whenNotPaused onlyOperator {
        super.burnBatch(account, ids, values);
    }

    function isApprovedForAll(address account, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        bool result = super.isApprovedForAll(account, operator);
        if (_operators[operator]) {
            return true;
        }
        return result;
    }

    function setOperator(address operator, bool isOperator_)
        external
        onlyOwner
    {
        _operators[operator] = isOperator_;
        emit Operator(operator, isOperator_);
    }

    function isOperator(address operator) external view returns (bool) {
        return _operators[operator];
    }

    function uri(uint256 tokenId) public pure override returns (string memory) {
        return (
            string(
                abi.encodePacked(
                    "https://api.yourserver.com/token/card/", // TODO: update base URI
                    StringsUpgradeable.toString(tokenId)
                )
            )
        );
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(from != DEAD_ADDRESS, "ERC1155: burn from the dead address");

        safeTransferFrom(from, DEAD_ADDRESS, id, amount, "");
        emit Burn(from, id, amount);
    }

    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual override {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(from != DEAD_ADDRESS, "ERC1155: burn from the dead address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            safeTransferFrom(from, DEAD_ADDRESS, ids[i], amounts[i], "");
        }
        emit BurnBatch(from, ids, amounts);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
