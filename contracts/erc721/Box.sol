/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/GachaBoxLib.sol";

contract BoxContract is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Box {
        GachaBoxLib.Type typeBox;
        bytes32 hashData;
    }

    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    CountersUpgradeable.Counter private _tokenIdCounter;
    mapping(address => bool) private _operators;
    mapping(uint256 => Box) private _boxOfTokenId;

    function initialize(string memory name_, string memory symbol_)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();
        __ERC721_init(name_, symbol_);
        __ERC721Burnable_init();
        __ERC721Enumerable_init();
    }

    event Operator(address operator, bool isOperator);
    event Mint(
        address recipient,
        uint256 tokenId,
        GachaBoxLib.Type typeBox,
        bytes32 hashData
    );
    event Burn(uint256 tokenId);

    modifier onlyOperator() {
        require(_operators[_msgSender()], "Box: Sender is not operator");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(
        address to,
        GachaBoxLib.Type typeBox,
        bytes32 hashData
    ) public onlyOperator returns (uint256) {
        require(
            typeBox <= GachaBoxLib.Type.GUILD_EXCLUSIVE,
            "Mint fail: Type box is invalid"
        );
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        Box storage box = _boxOfTokenId[tokenId];
        box.typeBox = typeBox;
        box.hashData = hashData;
        emit Mint(to, tokenId, typeBox, hashData);
        return tokenId;
    }

    function burn(uint256 tokenId)
        public
        virtual
        override
        whenNotPaused
        onlyOperator
    {
        _burn(tokenId);
    }

    function boxInformation(uint256 tokenId)
        public
        view
        returns (GachaBoxLib.Type typeBox, bytes32 hashData)
    {
        Box memory box = _boxOfTokenId[tokenId];
        typeBox = box.typeBox;
        hashData = box.hashData;
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

    /**
     *  @dev get all token held by a user address
     *  @param owner is the token holder
     */
    function getTokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        // get the number of token being hold by owner
        uint256 tokenCount = balanceOf(owner);

        if (tokenCount == 0) {
            // if owner has no balance return an empty array
            return new uint256[](0);
        } else {
            // query owner's tokens by index and add them to the token array
            uint256[] memory tokenList = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++)
                tokenList[i] = tokenOfOwnerByIndex(owner, i);
            return tokenList;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override {
        safeTransferFrom(ownerOf(tokenId), DEAD_ADDRESS, tokenId);
        require(ownerOf(tokenId) == DEAD_ADDRESS, "Burn fail");
        emit Burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://api.yourserver.com/token/cue/";
    }

    function _isApprovedOrOwner(address _address, uint256 _tokenId)
        internal
        view
        override
        returns (bool)
    {
        if (_operators[_address]) {
            return true;
        }
        return _isApprovedOrOwner(_address, _tokenId);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
